import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/image_upload_service.dart';

class CreateCoachReportScreen extends ConsumerStatefulWidget {
  const CreateCoachReportScreen({super.key});

  @override
  ConsumerState<CreateCoachReportScreen> createState() => _CreateCoachReportScreenState();
}

class _CreateCoachReportScreenState extends ConsumerState<CreateCoachReportScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitReport() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título y la descripción son obligatorios.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sessionUser = ref.read(currentUserProvider);
      if (sessionUser == null) throw Exception("Usuario no autenticado");

      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await ImageUploadService.uploadProductImage(_selectedImage!);
      }

      final reportData = {
        'title': title,
        'description': description,
        'attachmentUrl': imageUrl,
        'coachId': sessionUser.id,
        'coachName': '${sessionUser.name} ${sessionUser.lastName}',
        'category': sessionUser.category ?? 'Sin categoría',
      };

      await ref.read(firestoreServiceProvider).addCoachReport(reportData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe enviado con éxito a la directiva.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar el informe: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Enviar Informe'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Este informe será enviado de forma privada a la directiva y coordinadores.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleController,
                    style: AppTypography.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: 'Título del Informe',
                      hintText: 'Ej: Novedad sobre partido / Material faltante',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _descriptionController,
                    style: AppTypography.bodyLarge,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Descripción detallada',
                      hintText: 'Explica lo sucedido...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  JNCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Archivo Adjunto (Opcional)', style: AppTypography.titleSmall),
                        const SizedBox(height: 12),
                        if (_selectedImage != null) ...[
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImage!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.white),
                                onPressed: () {
                                  setState(() => _selectedImage = null);
                                },
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.attach_file),
                          label: Text(_selectedImage == null ? 'Adjuntar Imagen' : 'Cambiar Imagen'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  JNButton(
                    text: 'Enviar Informe',
                    onPressed: _submitReport,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
