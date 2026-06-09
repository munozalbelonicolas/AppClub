import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/models/user_session.dart';

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

  String? _avatarPath;
  String? _aptoFisicoPath;
  DateTime? _aptoFisicoExpiry;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider) ?? SessionMocks.users['padre']!;
    
    _nameController = TextEditingController(text: user.name);
    _lastNameController = TextEditingController(text: user.lastName);
    _dniController = TextEditingController(text: user.dni ?? '');
    _weightController = TextEditingController(text: user.weight ?? '');
    _heightController = TextEditingController(text: user.height ?? '');
    _ageController = TextEditingController(text: user.age?.toString() ?? '');
    _fatherNameController = TextEditingController(text: user.fatherName ?? '');
    _motherNameController = TextEditingController(text: user.motherName ?? '');
    
    _avatarPath = user.avatarUrl;
    _aptoFisicoPath = user.aptoFisicoUrl;
    _aptoFisicoExpiry = user.aptoFisicoExpiry;
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
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() {
          _avatarPath = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  Future<void> _pickAptoFisico() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file != null) {
        setState(() {
          _aptoFisicoPath = file.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking medical card: $e');
    }
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _aptoFisicoExpiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _aptoFisicoExpiry) {
      setState(() {
        _aptoFisicoExpiry = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = ref.read(currentUserProvider) ?? SessionMocks.users['padre']!;
    
    try {
      final updatedData = {
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
        'aptoFisicoExpiry': _aptoFisicoExpiry != null ? Timestamp.fromDate(_aptoFisicoExpiry!) : null,
      };

      // Update in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.id).update(updatedData);

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
        weight: _weightController.text.trim(),
        height: _heightController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        fatherName: _fatherNameController.text.trim(),
        motherName: _motherNameController.text.trim(),
        aptoFisicoUrl: _aptoFisicoPath,
        aptoFisicoExpiry: _aptoFisicoExpiry,
        hasPendingDebt: user.hasPendingDebt,
        avatarUrl: _avatarPath,
      );

      ref.read(currentUserProvider.notifier).state = updatedSession;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil guardado correctamente!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider) ?? SessionMocks.users['padre']!;
    
    // Warn if expired or within 30 days of expiry
    final bool showAptoWarning = user.isAptoFisicoWarning || _aptoFisicoExpiry == null;
    final bool showAptoExpired = user.isAptoFisicoExpired;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi Perfil y Ficha'),
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
                        colors: [AppColors.error.withValues(alpha: 0.2), AppColors.surface],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Deuda Pendiente', style: AppTypography.titleMedium.copyWith(color: AppColors.error)),
                                const SizedBox(height: 2),
                                Text(
                                  'Registras una cuota mensual pendiente. Regulariza tu situación para evitar la suspensión.',
                                  style: AppTypography.bodySmall,
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
                        colors: [AppColors.warning.withValues(alpha: 0.15), AppColors.surface],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            showAptoExpired ? Icons.cancel : Icons.notification_important_outlined,
                            color: showAptoExpired ? AppColors.error : AppColors.warning,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  showAptoExpired ? 'Apto Físico Vencido' : 'Apto Físico por Vencer',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: showAptoExpired ? AppColors.error : AppColors.warning,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _aptoFisicoExpiry == null
                                      ? 'No has cargado tu certificado de apto físico obligatorio.'
                                      : 'Tu certificado médico vence pronto el ${_formatDate(_aptoFisicoExpiry!)}. Por favor, sube uno nuevo.',
                                  style: AppTypography.bodySmall,
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
                            backgroundColor: AppColors.surfaceLight,
                            backgroundImage: _avatarPath != null
                                ? ( _avatarPath!.startsWith('http')
                                    ? NetworkImage(_avatarPath!) as ImageProvider
                                    : FileImage(File(_avatarPath!)) as ImageProvider )
                                : null,
                            child: _avatarPath == null
                                ? const Icon(Icons.person, size: 48, color: AppColors.textTertiary)
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
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
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
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Personal Data Section ────────────────
                  Text('Datos del Jugador', style: AppTypography.labelMedium),
                  const SizedBox(height: 8),
                  
                  JNCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: AppTypography.bodyLarge,
                          decoration: const InputDecoration(labelText: 'Nombre'),
                          validator: (v) => v == null || v.isEmpty ? 'Ingresa el nombre' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          style: AppTypography.bodyLarge,
                          decoration: const InputDecoration(labelText: 'Apellido'),
                          validator: (v) => v == null || v.isEmpty ? 'Ingresa el apellido' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dniController,
                          style: AppTypography.bodyLarge,
                          decoration: const InputDecoration(labelText: 'DNI'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _ageController,
                                style: AppTypography.bodyLarge,
                                decoration: const InputDecoration(labelText: 'Edad'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _heightController,
                                style: AppTypography.bodyLarge,
                                decoration: const InputDecoration(labelText: 'Altura (ej. 1.55 m)'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _weightController,
                                style: AppTypography.bodyLarge,
                                decoration: const InputDecoration(labelText: 'Peso (ej. 45 kg)'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Parents Data Section ─────────────────
                  Text('Datos Familiares', style: AppTypography.labelMedium),
                  const SizedBox(height: 8),

                  JNCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _fatherNameController,
                          style: AppTypography.bodyLarge,
                          decoration: const InputDecoration(labelText: 'Nombre y Apellido del Padre'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _motherNameController,
                          style: AppTypography.bodyLarge,
                          decoration: const InputDecoration(labelText: 'Nombre y Apellido de la Madre'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Physical Fitness Section ─────────────
                  Text('Certificado Médico (Apto Físico)', style: AppTypography.labelMedium),
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
                                    _aptoFisicoPath == null ? 'No cargado' : 'Archivo certificado cargado',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: _aptoFisicoPath == null ? AppColors.textSecondary : AppColors.success,
                                    ),
                                  ),
                                  if (_aptoFisicoExpiry != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Vence el: ${_formatDate(_aptoFisicoExpiry!)}',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: showAptoWarning ? AppColors.warning : AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_month, color: AppColors.primary),
                              onPressed: () => _selectExpiryDate(context),
                              tooltip: 'Seleccionar fecha de vencimiento',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_aptoFisicoPath != null && !_aptoFisicoPath!.startsWith('http')) ...[
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
                        JNButton(
                          label: _aptoFisicoPath == null ? 'Cargar Certificado' : 'Cambiar Certificado',
                          onPressed: _pickAptoFisico,
                          variant: JNButtonVariant.outline,
                          icon: Icons.upload_file,
                        ),
                      ],
                    ),
                  ),

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
