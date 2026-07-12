import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/app_logger.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';

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
          _aptoFisicoExpiry = DateTime.now().add(const Duration(days: 365));
        });
      }
    } catch (e) {
      AppLogger.error('Error picking medical card', error: e, tag: 'App');
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
          SnackBar(
            content: const Text('Perfil del jugador actualizado'),
            backgroundColor: context.colors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.error('Error saving child profile', error: e, tag: 'App');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: context.colors.error,
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
      backgroundColor: context.colors.background,
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
                'Toca para cambiar foto',
                style: context.typography.labelSmall.copyWith(
                  color: context.colors.textTertiary,
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text('Datos del Jugador', style: context.typography.titleLarge),
            const SizedBox(height: 12),
            JNCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: context.typography.bodyLarge,
                    decoration: const InputDecoration(labelText: 'Nombre'),
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
                    decoration: const InputDecoration(labelText: 'Apellido'),
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
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ageController,
                          style: context.typography.bodyLarge,
                          decoration: const InputDecoration(labelText: 'Edad'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          style: context.typography.bodyLarge,
                          decoration: const InputDecoration(labelText: 'Altura (ej. 155)'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          style: context.typography.bodyLarge,
                          decoration: const InputDecoration(labelText: 'Peso (ej. 45)'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Apto Físico', style: context.typography.titleLarge),
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
                            ? context.colors.error
                            : context.colors.success,
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
                              style: context.typography.titleMedium.copyWith(
                                color: showAptoExpired
                                    ? context.colors.error
                                    : context.colors.success,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _aptoFisicoExpiry == null
                                  ? 'Sube el certificado médico.'
                                  : 'Vence el ${_formatDate(_aptoFisicoExpiry!)}.',
                              style: context.typography.bodySmall,
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
                        border: Border.all(color: context.colors.border),
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