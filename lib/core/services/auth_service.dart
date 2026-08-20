import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_theme_colors.dart';
import '../models/user_session.dart';
import '../providers/session_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_logger.dart';
import 'notification_service.dart';
import 'onesignal_service.dart';

class AuthService {
  final Ref _ref;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '173425300822-o1lc1t0e5prjbtmkb7n06se95cv07u7o.apps.googleusercontent.com',
  );
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  AuthService(this._ref) {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((firebaseUser) {
      if (firebaseUser == null) {
        final currentSession = _ref.read(currentUserProvider);
        if (currentSession == null || !currentSession.id.startsWith('mock_uid_')) {
          _userSubscription?.cancel();
          _userSubscription = null;
          _ref.read(currentUserProvider.notifier).state = null;
        }
      } else {
        _syncUserProfile(
          firebaseUser.uid,
          firebaseUser.email ?? '',
          firebaseUser.displayName ?? '',
          emailVerified: firebaseUser.emailVerified,
        );
      }
    });
  }

  Future<UserSession?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // If email is not verified, but status might be active in DB, we should sync,
        // but we'll enforce email verification in the logic.
        return await _syncUserProfile(
          firebaseUser.uid,
          firebaseUser.email ?? email,
          firebaseUser.displayName ?? '',
          emailVerified: firebaseUser.emailVerified,
        );
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Email Sign-In failed', error: e, tag: 'AuthService');
      rethrow;
    }
    return null;
  }

  Future<UserSession?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String lastName,
    required String phone1,
    String? phone2,
    String? dni,
    String role = 'tutor',
  }) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        try {
          await firebaseUser.sendEmailVerification();
        } catch (e) {
          AppLogger.warning('Could not send email verification: $e', tag: 'AuthService');
        }

        final session = await _syncUserProfile(
          firebaseUser.uid,
          email,
          '$name $lastName',
          isNewRegistration: true,
          phone1: phone1,
          phone2: phone2,
          dni: dni,
          emailVerified: firebaseUser.emailVerified,
          role: role,
        );
        return session;
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Email Registration failed (FirebaseAuthException)', error: e, tag: 'AuthService');
      rethrow;
    } catch (e) {
      AppLogger.error('Email Registration failed (General / Firestore)', error: e, tag: 'AuthService');
      rethrow;
    }
    return null;
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      AppLogger.error('Error sending password reset email', error: e, tag: 'AuthService');
      rethrow;
    }
  }

  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload(); // Re-fetch user data from Firebase
      final refreshedUser = _auth.currentUser; // Get a fresh reference
      if (refreshedUser != null && refreshedUser.emailVerified) {
        final session = _ref.read(currentUserProvider);
        if (session != null) {
          _ref.read(currentUserProvider.notifier).state = session.copyWith(
            emailVerified: true,
          );
        }
        return true;
      }
    }
    return false;
  }

  /// Tries real Google Sign-In.
  /// If it fails due to config/SHA-1 errors, falls back to a simulated Google Sign-In dialog
  /// so the user can test the email 'munozalbelonicolas@gmail.com' and other roles.
  Future<UserSession?> signInWithGoogle(
    BuildContext context,
  ) async {
    try {
      // 1. Tries to sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        return await _syncUserProfile(
          firebaseUser.uid,
          firebaseUser.email ?? '',
          firebaseUser.displayName ?? '',
        );
      }
    } catch (e) {
      AppLogger.warning('Google Sign-In failed or not configured: $e', tag: 'AuthService');

      if (!context.mounted) return null;

      // En modo debug mostramos el selector demo para facilitar pruebas
      if (kDebugMode) {
        return await _showDemoGoogleSignInDialog(context, errorDetails: e.toString());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo iniciar sesión con Google. Por favor ingresa con tu correo y contraseña.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    return null;
  }

  /// Synchronizes the authenticated user profile with Firestore
  Future<UserSession> _syncUserProfile(
    String uid,
    String email,
    String displayName, {
    bool isNewRegistration = false,
    String? phone1,
    String? phone2,
    String? dni,
    bool emailVerified = true, // By default true for Google Sign In demo
    String? role,
  }) async {
    final docRef = _db.collection('users').doc(uid);
    final docSnap = await docRef.get();

    final String name = displayName.split(' ').first;
    final String lastName = displayName.split(' ').length > 1
        ? displayName.split(' ').sublist(1).join(' ')
        : '';

    UserSession session;

    if (docSnap.exists && !isNewRegistration) {
      final data = docSnap.data()!;
      final userRole = data['role'] ?? 'tutor';
      final bool isAdminRole = userRole == 'directivo' || userRole == 'secretario';
      final List<String>? rawAssignedCats = isAdminRole
          ? null
          : (data['assignedCategories'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((c) => !c.toLowerCase().contains('sub-12') && !c.toLowerCase().contains('sub12'))
              .toList();
      String? userCategory = isAdminRole ? null : data['category'];
      if (userCategory != null &&
          (userCategory.toLowerCase().contains('sub-12') || userCategory.toLowerCase().contains('sub12'))) {
        userCategory = (rawAssignedCats != null && rawAssignedCats.isNotEmpty) ? rawAssignedCats.first : null;
      }
      if (userRole == 'dt' && rawAssignedCats != null && rawAssignedCats.isNotEmpty) {
        if (userCategory == null || !rawAssignedCats.contains(userCategory)) {
          userCategory = rawAssignedCats.first;
        }
      }

      String resolvedName = (data['name']?.toString() ?? '').trim();
      String resolvedLastName = (data['lastName']?.toString() ?? '').trim();

      if (resolvedName.isEmpty && resolvedLastName.isEmpty) {
        final disp = (data['displayName']?.toString() ??
                data['fullName']?.toString() ??
                displayName)
            .trim();
        if (disp.isNotEmpty) {
          final parts = disp.split(' ');
          resolvedName = parts.first;
          resolvedLastName =
              parts.length > 1 ? parts.sublist(1).join(' ') : '';
        } else {
          resolvedName = email.split('@').first;
        }
      }

      session = UserSession(
        id: uid,
        name: resolvedName,
        lastName: resolvedLastName,
        email: email,
        role: userRole,
        status: data['status'] ?? 'active',
        emailVerified: emailVerified,
        category: userCategory,
        assignedCategories: rawAssignedCats,
        dni: data['dni'],
        weight: data['weight'],
        height: data['height'],
        age: data['age'],
        birthDate: data['birthDate'] != null
            ? (data['birthDate'] as Timestamp).toDate()
            : null,
        fatherName: data['fatherName'],
        motherName: data['motherName'],
        aptoFisicoUrl: data['aptoFisicoUrl'],
        aptoFisicoExpiry: data['aptoFisicoExpiry'] != null
            ? (data['aptoFisicoExpiry'] as Timestamp).toDate()
            : null,
        hasPendingDebt: data['hasPendingDebt'] ?? false,
        avatarUrl: data['avatarUrl'],
        phone1: data['phone1'],
        phone2: data['phone2'],
        termsAcceptedAt: data['termsAcceptedAt'] != null
            ? (data['termsAcceptedAt'] as Timestamp).toDate()
            : null,
        termsVersion: data['termsVersion'],
      );

      // Clean up category from Firestore if user is admin role but had category stored,
      // or if DT has stale category / assignedCategories
      final Map<String, dynamic> updates = {};
      if (data['emailVerified'] != emailVerified) {
        updates['emailVerified'] = emailVerified;
      }
      if (isAdminRole && data['category'] != null) {
        updates['category'] = FieldValue.delete();
      }
      if (isAdminRole && data['assignedCategories'] != null) {
        updates['assignedCategories'] = FieldValue.delete();
      }
      if (userRole == 'dt') {
        if (data['category'] != userCategory) {
          updates['category'] = userCategory ?? FieldValue.delete();
        }
        final List<dynamic>? currentAssigned = data['assignedCategories'] as List<dynamic>?;
        if (currentAssigned != null && rawAssignedCats != null && currentAssigned.length != rawAssignedCats.length) {
          updates['assignedCategories'] = rawAssignedCats;
        }
      }
      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
    } else {
      // New user
      final isDirector =
          email.trim().toLowerCase() == 'munozalbelonicolas@gmail.com';
      final String initialRole = role ?? (isDirector ? 'directivo' : 'tutor');
      const String? initialCategory = null;
      final String initialStatus = isDirector
          ? 'active'
          : (initialRole == 'socio' ? 'pending_approval' : 'pending_children');

      final newProfile = {
        'name': name,
        'lastName': lastName,
        'email': email,
        'role': initialRole,
        'status': initialStatus,
        'emailVerified': emailVerified,
        'category': initialCategory,
        'hasPendingDebt': false,
        'createdAt': FieldValue.serverTimestamp(),
        'phone1': phone1,
        'phone2': phone2,
        'dni': ?dni,
        'termsAcceptedAt':
            isNewRegistration ? FieldValue.serverTimestamp() : null,
        'termsVersion': isNewRegistration ? '1.0' : null,
      };

      await docRef.set(newProfile, SetOptions(merge: true));

      session = UserSession(
        id: uid,
        name: name,
        lastName: lastName,
        email: email,
        role: initialRole,
        status: initialStatus,
        emailVerified: emailVerified,
        phone1: phone1,
        phone2: phone2,
        dni: dni,
        termsAcceptedAt: isNewRegistration ? DateTime.now() : null,
        termsVersion: isNewRegistration ? '1.0' : null,
      );
    }

    // Set up realtime listener
    _userSubscription?.cancel();
    _userSubscription = docRef.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final snapshotData = snapshot.data()!;
        final snapshotRole = snapshotData['role'] ?? 'tutor';
        final bool isSnapshotAdmin = snapshotRole == 'directivo' || snapshotRole == 'secretario';

        String resolvedSnapName = (snapshotData['name']?.toString() ?? '').trim();
        String resolvedSnapLastName = (snapshotData['lastName']?.toString() ?? '').trim();

        if (resolvedSnapName.isEmpty && resolvedSnapLastName.isEmpty) {
          final disp = (snapshotData['displayName']?.toString() ??
                  snapshotData['fullName']?.toString() ??
                  displayName)
              .trim();
          if (disp.isNotEmpty) {
            final parts = disp.split(' ');
            resolvedSnapName = parts.first;
            resolvedSnapLastName =
                parts.length > 1 ? parts.sublist(1).join(' ') : '';
          } else {
            resolvedSnapName = email.split('@').first;
          }
        }

        final rawSnapAssigned = isSnapshotAdmin
            ? null
            : (snapshotData['assignedCategories'] as List<dynamic>?)
                ?.map((e) => e.toString().trim())
                .where((c) => !c.toLowerCase().contains('sub-12') && !c.toLowerCase().contains('sub12'))
                .toList();
        String? resolvedSnapCat = isSnapshotAdmin ? null : snapshotData['category'];
        if (resolvedSnapCat != null &&
            (resolvedSnapCat.toLowerCase().contains('sub-12') || resolvedSnapCat.toLowerCase().contains('sub12'))) {
          resolvedSnapCat = (rawSnapAssigned != null && rawSnapAssigned.isNotEmpty) ? rawSnapAssigned.first : null;
        }
        if (snapshotRole == 'dt' && rawSnapAssigned != null && rawSnapAssigned.isNotEmpty) {
          if (resolvedSnapCat == null || !rawSnapAssigned.contains(resolvedSnapCat)) {
            resolvedSnapCat = rawSnapAssigned.first;
          }
        }

        final updatedSession = UserSession(
          id: uid,
          name: resolvedSnapName,
          lastName: resolvedSnapLastName,
          email: email,
          role: snapshotRole,
          status: snapshotData['status'] ?? 'active',
          emailVerified: snapshotData['emailVerified'] ?? emailVerified,
          category: resolvedSnapCat,
          assignedCategories: rawSnapAssigned,
          dni: snapshotData['dni'],
          weight: snapshotData['weight'],
          height: snapshotData['height'],
          age: snapshotData['age'],
          birthDate: snapshotData['birthDate'] != null
              ? (snapshotData['birthDate'] as Timestamp).toDate()
              : null,
          fatherName: snapshotData['fatherName'],
          motherName: snapshotData['motherName'],
          aptoFisicoUrl: snapshotData['aptoFisicoUrl'],
          aptoFisicoExpiry: snapshotData['aptoFisicoExpiry'] != null
              ? (snapshotData['aptoFisicoExpiry'] as Timestamp).toDate()
              : null,
          hasPendingDebt: snapshotData['hasPendingDebt'] ?? false,
          avatarUrl: snapshotData['avatarUrl'],
          phone1: snapshotData['phone1'],
          phone2: snapshotData['phone2'],
          termsAcceptedAt: snapshotData['termsAcceptedAt'] != null
              ? (snapshotData['termsAcceptedAt'] as Timestamp).toDate()
              : null,
          termsVersion: snapshotData['termsVersion'],
        );
        // Only update session state — do NOT call saveTokenUser or startNotificationStream
        // here to avoid a feedback loop (saving token updates 'updatedAt' which triggers
        // this listener again, causing infinite Firestore writes).
        _ref.read(currentUserProvider.notifier).state = updatedSession;
      }
    });

    // Save FCM token and start notification stream exactly once at login
    NotificationService().saveTokenUser(uid);
    NotificationService().startNotificationStream(uid, userCategory: session.category);

    // Sync OneSignal user ID & segment tags
    OneSignalService().loginUser(uid);
    OneSignalService().setUserTags({
      'role': session.role,
      if (session.category != null) 'category': session.category!,
    });

    return session;
  }

  /// Displays a dialog simulating Google Sign-In with preset emails and typing field
  Future<UserSession?> _showDemoGoogleSignInDialog(
    BuildContext context, {
    String? errorDetails,
  }) async {
    final emailController = TextEditingController(
      text: 'munozalbelonicolas@gmail.com',
    );
    final nameController = TextEditingController(text: 'Nicolás');
    final lastNameController = TextEditingController(text: 'Muñoz Albelo');
    final formKey = GlobalKey<FormState>();

    return showDialog<UserSession>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(color: context.colors.border, width: 0.5),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.g_mobiledata_rounded,
                    color: context.colors.primary,
                    size: 36,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Google Sign-In (Demo)',
                    style: context.typography.titleLarge,
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (errorDetails != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: SelectableText(
                            'Error técnico:\n$errorDetails',
                            style: context.typography.bodySmall.copyWith(
                              color: Colors.redAccent,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        'No se detectó configuración SHA-1 o Google Play Services. Mostrando selector demo de cuenta Google.',
                        style: context.typography.bodySmall.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailController,
                        style: context.typography.bodyLarge,
                        decoration: const InputDecoration(
                          labelText: 'Email de Google',
                        ),
                        validator: (v) => v != null && v.contains('@')
                            ? null
                            : 'Email inválido',
                        onChanged: (val) {
                          setDialogState(() {
                            if (val.trim().toLowerCase() ==
                                'munozalbelonicolas@gmail.com') {
                              nameController.text = 'Nicolás';
                              lastNameController.text = 'Muñoz Albelo';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: nameController,
                        style: context.typography.bodyLarge,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lastNameController,
                        style: context.typography.bodyLarge,
                        decoration: const InputDecoration(
                          labelText: 'Apellido',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Predefinidos de prueba:',
                        style: context.typography.labelSmall.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text(
                              'munozalbelonicolas@gmail.com (Director)',
                            ),
                            labelStyle: context.typography.labelSmall.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            backgroundColor: context.colors.primary.withValues(
                              alpha: 0.2,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                emailController.text =
                                    'munozalbelonicolas@gmail.com';
                                nameController.text = 'Nicolás';
                                lastNameController.text = 'Muñoz Albelo';
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text(
                              'dt.prueba@gmail.com (DT 2021)',
                            ),
                            labelStyle: context.typography.labelSmall.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            backgroundColor: context.colors.surfaceLight,
                            onPressed: () {
                              setDialogState(() {
                                emailController.text = 'dt.prueba@gmail.com';
                                nameController.text = 'Pablo';
                                lastNameController.text = 'Ramírez';
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text(
                              'tutor.prueba@gmail.com (Tutor)',
                            ),
                            labelStyle: context.typography.labelSmall.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            backgroundColor: context.colors.surfaceLight,
                            onPressed: () {
                              setDialogState(() {
                                emailController.text = 'tutor.prueba@gmail.com';
                                nameController.text = 'Carlos';
                                lastNameController.text = 'Gutiérrez';
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final email = emailController.text.trim();
                      final name = nameController.text.trim();
                      final lastName = lastNameController.text.trim();
                      final mockUid = 'mock_uid_${email.hashCode.abs()}';

                      final session = await _syncUserProfile(
                        mockUid,
                        email,
                        '$name $lastName',
                      );
                      if (context.mounted) {
                        Navigator.pop(context, session);
                      }
                    }
                  },
                  child: const Text('Iniciar Sesión'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Sign out from Firebase and Google
  Future<void> signOut() async {
    _userSubscription?.cancel();
    _userSubscription = null;
    await OneSignalService().logoutUser();
    await _googleSignIn.signOut();
    await _auth.signOut();
    _ref.read(currentUserProvider.notifier).state = null;
  }

  Future<void> completeRegistration({
    String? phone1,
    String? phone2,
  }) async {
    final session = _ref.read(currentUserProvider);
    if (session == null) throw Exception('No session found');

    final docRef = _db.collection('users').doc(session.id);
    final updateData = <String, dynamic>{
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'termsVersion': '1.0',
    };
    
    if (phone1 != null) updateData['phone1'] = phone1;
    if (phone2 != null) updateData['phone2'] = phone2;

    await docRef.update(updateData);

    // We can rely on the realtime listener to update the session provider, 
    // but we can also manually trigger a sync just in case.
    await _syncUserProfile(
      session.id,
      session.email,
      '${session.name} ${session.lastName}',
    );
  }

  /// Deletes the current authenticated user account and updates Firestore user status.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    final session = _ref.read(currentUserProvider);

    if (session != null) {
      await _db.collection('users').doc(session.id).update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
      });
    }

    if (user != null) {
      await user.delete();
    }

    await signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});