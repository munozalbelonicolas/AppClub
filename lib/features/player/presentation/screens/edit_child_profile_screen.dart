import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_button.dart';

class EditChildProfileScreen extends ConsumerStatefulWidget {
  final String childId;
  final Map<String, dynamic> childData;

  const EditChildProfileScreen({
    super.key,
    required this.childId,
    required this.childData,
  });

  @override
  ConsumerState<EditChildProfileScreen> createState() =>
      _EditChildProfileScreenState();
}

class _EditChildProfileScreenState extends ConsumerState<EditChildProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _lastNameController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;

  String? _avatarPath;
  String? _aptoFisicoPath;
  DateTime? _aptoFisicoExpiry;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.childData;

    _nameController = TextEditingController(text: data['name'] ?? '');
    _lastNameController = TextEditingController(text: data['lastName'] ?? '');
    _weightController = TextEditingController(text: data['weight']?.toString() ?? '');
    _heightController = TextEditingController(text: data['height']?.toString() ?? '');
    _ageController = TextEditingController(text: data['age']?.toString() ?? '');

    _avatarPath = data['avatarUrl'];
    _aptoFisicoPath = data['aptoFisicoUrl'];
    
    if (data['aptoFisicoExpiry'] != null && data['aptoFisicoExpiry'] is Timestamp) {
      _aptoFisicoExpiry = (data['aptoFisicoExpiry'] as Timestamp).toDate();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
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
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
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
      initialDate:
          _aptoFisicoExpiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
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

    try {
      final updatedData = {
        'name': _nameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'weight': _weightController.text.trim(),
        'height': _heightController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'avatarUrl': _avatarPath,
        'aptoFisicoUrl': _aptoFisicoPath,
        'aptoFisicoExpiry': _aptoFisicoExpiry != null
            ? Timestamp.fromDate(_aptoFisicoExpiry!)
            : null,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.childId)
          .update(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil del jugador actualizado'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving child profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bool showAptoExpired = _aptoFisicoExpiry == null ||
        _aptoFisicoExpiry!.isBefore(DateTime.now().add(const Duration(days: 30)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editar Jugador'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 54,
                      backgroundColor: AppColors.surfaceLight,
                      backgroundImage: _avatarPath != null
                          ? (_avatarPath!.startsWith('http')
                                ? NetworkImage(_avatarPath!)
                                      as ImageProvider
                                : FileImage(File(_avatarPath!))
                                      as ImageProvider)
                          : null,
                      child: _avatarPath == null
                          ? const Icon(
                              Icons.person,
                              size: 48,
                              color: AppColors.textTertiary,
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
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
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
                'Toca para cambiar foto',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text('Datos del Jugador', style: AppTypography.titleLarge),
            const SizedBox(height: 12),
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
                          decoration: const InputDecoration(labelText: 'Altura (ej. 155)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          style: AppTypography.bodyLarge,
                          decoration: const InputDecoration(labelText: 'Peso (ej. 45)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Apto Físico', style: AppTypography.titleLarge),
            const SizedBox(height: 12),
            JNCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        showAptoExpired
                            ? Icons.cancel
                            : Icons.check_circle,
                        color: showAptoExpired
                            ? AppColors.error
                            : AppColors.success,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              showAptoExpired
                                  ? 'Apto Físico Vencido/Faltante'
                                  : 'Apto Físico Válido',
                              style: AppTypography.titleMedium.copyWith(
                                color: showAptoExpired
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _aptoFisicoExpiry == null
                                  ? 'Sube el certificado médico.'
                                  : 'Vence el ${_formatDate(_aptoFisicoExpiry!)}.',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_aptoFisicoPath != null) ...[
                    Container(
                      height: 150,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                        image: DecorationImage(
                          image: _aptoFisicoPath!.startsWith('http')
                              ? NetworkImage(_aptoFisicoPath!) as ImageProvider
                              : FileImage(File(_aptoFisicoPath!)) as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                  JNButton(
                    label: _aptoFisicoPath == null ? 'Subir Apto Físico' : 'Cambiar Imagen',
                    icon: Icons.upload_file,
                    variant: JNButtonVariant.outline,
                    onPressed: _pickAptoFisico,
                  ),
                  const SizedBox(height: 12),
                  JNButton(
                    label: _aptoFisicoExpiry == null
                        ? 'Establecer Vencimiento'
                        : 'Cambiar Vencimiento',
                    icon: Icons.calendar_month,
                    variant: JNButtonVariant.outline,
                    onPressed: () => _selectExpiryDate(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            JNButton(
              label: 'Guardar Cambios',
              isLoading: _isLoading,
              onPressed: _saveProfile,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
