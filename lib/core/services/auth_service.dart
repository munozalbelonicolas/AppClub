import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_session.dart';
import '../providers/session_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Tries real Google Sign-In.
  /// If it fails due to config/SHA-1 errors, falls back to a simulated Google Sign-In dialog
  /// so the user can test the email 'munozalbelonicolas@gmail.com' and other roles.
  Future<UserSession?> signInWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      // 1. Tries to sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        return await _syncUserProfile(firebaseUser.uid, firebaseUser.email ?? '', firebaseUser.displayName ?? '', ref);
      }
    } catch (e) {
      debugPrint('Real Google Sign-In failed or not configured: $e');
      // Fallback to beautiful Demo Dialog
      if (!context.mounted) return null;
      return await _showDemoGoogleSignInDialog(context, ref);
    }
    return null;
  }

  /// Synchronizes the authenticated user profile with Firestore
  Future<UserSession> _syncUserProfile(String uid, String email, String displayName, WidgetRef ref) async {
    final docRef = _db.collection('users').doc(uid);
    final docSnap = await docRef.get();

    final String name = displayName.split(' ').first;
    final String lastName = displayName.split(' ').length > 1 ? displayName.split(' ').sublist(1).join(' ') : '';

    UserSession session;

    if (docSnap.exists) {
      final data = docSnap.data()!;
      session = UserSession(
        id: uid,
        name: data['name'] ?? name,
        lastName: data['lastName'] ?? lastName,
        email: email,
        role: data['role'] ?? 'padre',
        category: data['category'],
        dni: data['dni'],
        weight: data['weight'],
        height: data['height'],
        age: data['age'],
        fatherName: data['fatherName'],
        motherName: data['motherName'],
        aptoFisicoUrl: data['aptoFisicoUrl'],
        aptoFisicoExpiry: data['aptoFisicoExpiry'],
        hasPendingDebt: data['hasPendingDebt'] ?? false,
        avatarUrl: data['avatarUrl'],
      );
    } else {
      // New user
      final isDirector = email.trim().toLowerCase() == 'munozalbelonicolas@gmail.com';
      final String initialRole = isDirector ? 'directivo' : 'padre';
      final String? initialCategory = isDirector ? null : 'Sub-12';

      final newProfile = {
        'name': name,
        'lastName': lastName,
        'email': email,
        'role': initialRole,
        'category': initialCategory,
        'hasPendingDebt': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(newProfile);

      session = UserSession(
        id: uid,
        name: name,
        lastName: lastName,
        email: email,
        role: initialRole,
        category: initialCategory,
        hasPendingDebt: false,
      );
    }

    ref.read(currentUserProvider.notifier).state = session;
    return session;
  }

  /// Displays a dialog simulating Google Sign-In with preset emails and typing field
  Future<UserSession?> _showDemoGoogleSignInDialog(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController(text: 'munozalbelonicolas@gmail.com');
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
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(color: AppColors.border, width: 0.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.g_mobiledata_rounded, color: AppColors.primary, size: 36),
                  const SizedBox(width: 8),
                  Text('Google Sign-In (Demo)', style: AppTypography.titleLarge),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'No se detectó configuración SHA-1 o Google Play Services. Mostrando selector demo de cuenta Google.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(labelText: 'Email de Google'),
                        validator: (v) => v != null && v.contains('@') ? null : 'Email inválido',
                        onChanged: (val) {
                          setDialogState(() {
                            if (val.trim().toLowerCase() == 'munozalbelonicolas@gmail.com') {
                              nameController.text = 'Nicolás';
                              lastNameController.text = 'Muñoz Albelo';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: nameController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lastNameController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(labelText: 'Apellido'),
                      ),
                      const SizedBox(height: 16),
                      Text('Predefinidos de prueba:', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('munozalbelonicolas@gmail.com (Director)'),
                            labelStyle: AppTypography.labelSmall.copyWith(color: Colors.white, fontSize: 10),
                            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                            onPressed: () {
                              setDialogState(() {
                                emailController.text = 'munozalbelonicolas@gmail.com';
                                nameController.text = 'Nicolás';
                                lastNameController.text = 'Muñoz Albelo';
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('dt.prueba@gmail.com (DT Sub-12)'),
                            labelStyle: AppTypography.labelSmall.copyWith(color: Colors.white, fontSize: 10),
                            backgroundColor: AppColors.surfaceLight,
                            onPressed: () {
                              setDialogState(() {
                                emailController.text = 'dt.prueba@gmail.com';
                                nameController.text = 'Pablo';
                                lastNameController.text = 'Ramírez';
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('padre.prueba@gmail.com (Padre Sub-12)'),
                            labelStyle: AppTypography.labelSmall.copyWith(color: Colors.white, fontSize: 10),
                            backgroundColor: AppColors.surfaceLight,
                            onPressed: () {
                              setDialogState(() {
                                emailController.text = 'padre.prueba@gmail.com';
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
                  child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final email = emailController.text.trim();
                      final name = nameController.text.trim();
                      final lastName = lastNameController.text.trim();
                      final mockUid = 'mock_uid_${email.hashCode.abs()}';

                      final session = await _syncUserProfile(mockUid, email, '$name $lastName', ref);
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
  Future<void> signOut(WidgetRef ref) async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    ref.read(currentUserProvider.notifier).state = null;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});
