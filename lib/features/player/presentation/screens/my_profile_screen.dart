import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/user_session.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';
import 'edit_child_profile_screen.dart';
import 'register_player_screen.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _lastNameController;
  late TextEditingController _dniController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  late TextEditingController _fatherNameController;
  late TextEditingController _motherNameController;
  late TextEditingController _phone1Controller;
  late TextEditingController _phone2Controller;

  String? _avatarPath;
  String? _aptoFisicoPath;
  DateTime? _aptoFisicoExpiry;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);

    _nameController = TextEditingController(text: user?.name ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _dniController = TextEditingController(text: user?.dni ?? '');
    _weightController = TextEditingController(text: user?.weight ?? '');
    _heightController = TextEditingController(text: user?.height ?? '');
    _ageController = TextEditingController(text: user?.age?.toString() ?? '');
    _fatherNameController = TextEditingController(text: user?.fatherName ?? '');
    _motherNameController = TextEditingController(text: user?.motherName ?? '');
    _phone1Controller = TextEditingController(text: user?.phone1 ?? '');
    _phone2Controller = TextEditingController(text: user?.phone2 ?? '');

    _avatarPath = user?.avatarUrl;
    _aptoFisicoPath = user?.aptoFisicoUrl;
    _aptoFisicoExpiry = user?.aptoFisicoExpiry;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _dniController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _avatarPath = image.path;
        });
      }
    } catch (e) {
      AppLogger.error('Error picking avatar', error: e, tag: 'App');
    }
  }



  Stream<List<Map<String, dynamic>>> _fetchChildren(String tutorId) {
    return FirebaseFirestore.instance
        .collection('player_tutor_links')
        .where('tutorId', isEqualTo: tutorId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> children = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final playerId = data['playerId'] as String?;
        final status = data['status'] as String?;
        final isEnabledByTutor = data['isEnabledByTutor'] as bool? ?? true;
        if (playerId != null) {
          final playerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(playerId)
              .get();
          if (playerDoc.exists) {
            children.add({
              'id': playerDoc.id,
              ...playerDoc.data()!,
              'linkStatus': status,
              'isEnabledByTutor': isEnabledByTutor,
            });
          }
        }
      }
      return children;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final updatedData = user.role != 'jugador'
          ? {
              'name': _nameController.text.trim(),
              'lastName': _lastNameController.text.trim(),
              'dni': _dniController.text.trim(),
              'phone1': _phone1Controller.text.trim(),
              'phone2': _phone2Controller.text.trim(),
              'avatarUrl': _avatarPath,
            }
          : {
              'name': _nameController.text.trim(),
              'lastName': _lastNameController.text.trim(),
              'dni': _dniController.text.trim(),
              'weight': _weightController.text.trim(),
              'height': _heightController.text.trim(),
              'age': int.tryParse(_ageController.text.trim()),
              'fatherName': _fatherNameController.text.trim(),
              'motherName': _motherNameController.text.trim(),
              'avatarUrl': _avatarPath,
              'aptoFisicoUrl': _aptoFisicoPath,
              'aptoFisicoExpiry': _aptoFisicoExpiry != null
                  ? Timestamp.fromDate(_aptoFisicoExpiry!)
                  : null,
            };

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update(updatedData);

      // Update local state
      final updatedSession = UserSession(
        id: user.id,
        name: _nameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: user.email,
        role: user.role,
        category: user.category,
        childId: user.childId,
        dni: _dniController.text.trim(),
        weight: user.role == 'jugador' ? _weightController.text.trim() : null,
        height: user.role == 'jugador' ? _heightController.text.trim() : null,
        age: user.role == 'jugador' ? int.tryParse(_ageController.text.trim()) : null,
        fatherName: user.role == 'jugador' ? _fatherNameController.text.trim() : null,
        motherName: user.role == 'jugador' ? _motherNameController.text.trim() : null,
        aptoFisicoUrl: user.role == 'jugador' ? _aptoFisicoPath : null,
        aptoFisicoExpiry: user.role == 'jugador' ? _aptoFisicoExpiry : null,
        hasPendingDebt: user.hasPendingDebt,
        avatarUrl: _avatarPath,
        phone1: _phone1Controller.text.trim(),
        phone2: _phone2Controller.text.trim(),
      );

      ref.read(currentUserProvider.notifier).state = updatedSession;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Perfil guardado correctamente!'),
            backgroundColor: context.colors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.error('Error saving profile', error: e, tag: 'App');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Warn if expired or within 30 days of expiry
    final bool showAptoWarning = user.role == 'jugador' && (user.isAptoFisicoWarning || _aptoFisicoExpiry == null);
    final bool showAptoExpired = user.role == 'jugador' && user.isAptoFisicoExpired;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          user.role == 'jugador'
              ? 'Mi Perfil y Ficha'
              : user.role == 'padre' || user.role == 'tutor'
                  ? 'Mi Perfil (Tutor)'
                  : user.role == 'socio'
                      ? 'Mi Perfil (Socio)'
                      : 'Mi Perfil',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  // ─── Warning Banners ──────────────────────

                  // 1. Debt warning (Deuda Pendiente)
                  if (user.hasPendingDebt) ...[
                    JNCard(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.error.withValues(alpha: 0.2),
                          context.colors.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: context.colors.error.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: context.colors.error,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Deuda Pendiente',
                                  style: context.typography.titleMedium.copyWith(
                                    color: context.colors.error,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Registras una cuota mensual pendiente. Regulariza tu situación para evitar la suspensión.',
                                  style: context.typography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().shake(duration: 500.ms),
                    const SizedBox(height: 12),
                  ],

                  // 2. Physical fitness card warning (Apto Físico)
                  if (showAptoWarning) ...[
                    JNCard(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.warning.withValues(alpha: 0.15),
                          context.colors.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: context.colors.warning.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            showAptoExpired
                                ? Icons.cancel
                                : Icons.notification_important_outlined,
                            color: showAptoExpired
                                ? context.colors.error
                                : context.colors.warning,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  showAptoExpired
                                      ? 'Apto Físico Vencido'
                                      : 'Apto Físico por Vencer',
                                  style: context.typography.titleMedium.copyWith(
                                    color: showAptoExpired
                                        ? context.colors.error
                                        : context.colors.warning,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _aptoFisicoExpiry == null
                                      ? 'No has cargado tu certificado de apto físico obligatorio.'
                                      : 'Tu certificado médico vence pronto el ${_formatDate(_aptoFisicoExpiry!)}. Por favor, sube uno nuevo.',
                                  style: context.typography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().slideX(begin: 0.05),
                    const SizedBox(height: 16),
                  ],

                  // ─── Avatar Photo Card ────────────────────
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: context.colors.surfaceLight,
                            backgroundImage: _avatarPath != null
                                ? (_avatarPath!.startsWith('http')
                                      ? NetworkImage(_avatarPath!)
                                            as ImageProvider
                                      : FileImage(File(_avatarPath!))
                                            as ImageProvider)
                                : null,
                            child: _avatarPath == null
                                ? Icon(
                                    Icons.person,
                                    size: 48,
                                    color: context.colors.textTertiary,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAvatar,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: context.colors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Toca para cambiar foto de perfil',
                      style: context.typography.labelSmall.copyWith(
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Personal Data Section ────────────────
                  Text(
                    user.role == 'jugador' ? 'Datos del Jugador' : 'Datos Personales',
                    style: context.typography.labelMedium,
                  ),
                  const SizedBox(height: 8),

                  JNCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: context.typography.bodyLarge,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'-]")),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa el nombre';
                            if (!RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'-]+$").hasMatch(v.trim())) {
                              return 'Solo se permiten letras';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          style: context.typography.bodyLarge,
                          decoration: const InputDecoration(
                            labelText: 'Apellido',
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'-]")),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa el apellido';
                            if (!RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'-]+$").hasMatch(v.trim())) {
                              return 'Solo se permiten letras';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dniController,
                          style: context.typography.bodyLarge,
                          decoration: const InputDecoration(labelText: 'DNI'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Ingresa el DNI';
                            if (v.length < 7 || v.length > 8) {
                              return 'El DNI debe tener 7 u 8 dígitos';
                            }
                            return null;
                          },
                        ),
                        if (user.role != 'jugador') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone1Controller,
                            style: context.typography.bodyLarge,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono de Contacto 1',
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Ingresa el teléfono';
                              if (v.length != 10) return 'El teléfono debe tener 10 dígitos';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone2Controller,
                            style: context.typography.bodyLarge,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono de Contacto 2 (Opcional)',
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) {
                              if (v != null && v.isNotEmpty && v.length != 10) {
                                return 'El teléfono debe tener 10 dígitos';
                              }
                              return null;
                            },
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ageController,
                                  style: context.typography.bodyLarge,
                                  decoration: const InputDecoration(
                                    labelText: 'Edad',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _heightController,
                                  style: context.typography.bodyLarge,
                                  decoration: const InputDecoration(
                                    labelText: 'Altura (ej. 1.55 m)',
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _weightController,
                                  style: context.typography.bodyLarge,
                                  decoration: const InputDecoration(
                                    labelText: 'Peso (ej. 45 kg)',
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (user.role == 'padre' || user.role == 'tutor') ...[
                    // Hijos / Jugadores a cargo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jugadores Registrados (Hijos)',
                          style: context.typography.labelMedium,
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterPlayerScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Registrar Hijo'),
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _fetchChildren(user.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final children = snapshot.data ?? [];
                        if (children.isEmpty) {
                          return JNCard(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'No tienes hijos/jugadores vinculados.',
                                style: context.typography.bodySmall.copyWith(
                                  color: context.colors.textTertiary,
                                ),
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: children.map((child) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditChildProfileScreen(
                                        childId: child['id'],
                                        childData: child,
                                      ),
                                    ),
                                  );
                                },
                                child: JNCard(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: context.colors.surfaceLight,
                                      backgroundImage: child['avatarUrl'] != null &&
                                              child['avatarUrl'].toString().isNotEmpty
                                          ? (child['avatarUrl'].toString().startsWith('http')
                                              ? NetworkImage(child['avatarUrl'].toString())
                                                  as ImageProvider
                                              : FileImage(File(child['avatarUrl'].toString()))
                                                  as ImageProvider)
                                          : null,
                                      child: child['avatarUrl'] == null ||
                                              child['avatarUrl'].toString().isEmpty
                                          ? Icon(
                                              Icons.person,
                                              color: context.colors.textTertiary,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${child['name']} ${child['lastName'] ?? ''}',
                                            style: context.typography.titleMedium,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'DNI: ${child['dni'] ?? ''} · Cat: ${child['category'] ?? ''}',
                                            style: context.typography.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (child['linkStatus'] == 'linked'
                                                ? context.colors.success
                                                : context.colors.warning)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        child['linkStatus'] == 'linked'
                                            ? 'Vinculado'
                                            : 'Pendiente',
                                        style: context.typography.labelSmall.copyWith(
                                          color: child['linkStatus'] == 'linked'
                                              ? context.colors.success
                                              : context.colors.warning,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                  
                  if (user.role == 'jugador') ...[
                    // ─── Parents Data Section ─────────────────
                    Text('Datos Familiares', style: context.typography.labelMedium),
                    const SizedBox(height: 8),

                    JNCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _fatherNameController,
                            style: context.typography.bodyLarge,
                            decoration: const InputDecoration(
                              labelText: 'Nombre y Apellido del Tutor/a 1',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _motherNameController,
                            style: context.typography.bodyLarge,
                            decoration: const InputDecoration(
                              labelText: 'Nombre y Apellido del Tutor/a 2 (Opcional)',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── Physical Fitness Section ─────────────
                    Text(
                      'Certificado Médico (Apto Físico)',
                      style: context.typography.labelMedium,
                    ),
                    const SizedBox(height: 8),

                    JNCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _aptoFisicoPath == null
                                          ? 'No cargado'
                                          : 'Archivo certificado cargado',
                                      style: context.typography.titleMedium.copyWith(
                                        color: _aptoFisicoPath == null
                                            ? context.colors.textSecondary
                                            : context.colors.success,
                                      ),
                                    ),
                                    if (_aptoFisicoExpiry != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Vence el: ${_formatDate(_aptoFisicoExpiry!)}',
                                        style: context.typography.bodySmall.copyWith(
                                          color: showAptoWarning
                                              ? context.colors.warning
                                              : context.colors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_aptoFisicoPath != null &&
                              !_aptoFisicoPath!.startsWith('http')) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_aptoFisicoPath!),
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ─── Save Button ──────────────────────────
                  JNButton(
                    label: 'Guardar Cambios',
                    onPressed: _saveProfile,
                    size: JNButtonSize.large,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}