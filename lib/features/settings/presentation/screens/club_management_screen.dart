import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';

class ClubManagementScreen extends ConsumerStatefulWidget {
  const ClubManagementScreen({super.key});

  @override
  ConsumerState<ClubManagementScreen> createState() => _ClubManagementScreenState();
}

class _ClubManagementScreenState extends ConsumerState<ClubManagementScreen> {
  void _showAddClubDialog(BuildContext context, [Map<String, dynamic>? club]) {
    final nameController = TextEditingController(text: club?['name']);
    final logoController = TextEditingController(text: club?['logoUrl']);
    final isLocalNotifier = ValueNotifier<bool>(club?['isLocal'] ?? false);
    final isUploadingNotifier = ValueNotifier<bool>(false);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text(
            club == null ? 'Nuevo Club' : 'Editar Club',
            style: context.typography.titleLarge,
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre del Club'),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Ingresa el nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: isUploadingNotifier,
                    builder: (context, isUploading, child) {
                      return Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: logoController,
                              decoration: const InputDecoration(
                                labelText: 'Escudo/Logo',
                                hintText: 'Sube una imagen o pega URL...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isUploading)
                            const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else
                            IconButton(
                              icon: Icon(Icons.upload_file, color: context.colors.primary),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(source: ImageSource.gallery);
                                if (picked != null) {
                                  isUploadingNotifier.value = true;
                                  try {
                                    final url = await ImageUploadService.uploadProductImage(File(picked.path));
                                    logoController.text = url;
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error),
                                      );
                                    }
                                  } finally {
                                    isUploadingNotifier.value = false;
                                  }
                                }
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: isLocalNotifier,
                    builder: (context, isLocal, child) {
                      return SwitchListTile(
                        title: const Text('¿Es el Club Local?'),
                        value: isLocal,
                        activeThumbColor: context.colors.primary,
                        onChanged: (val) {
                          isLocalNotifier.value = val;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            JNButton(
              label: 'Guardar',
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final data = {
                    'name': nameController.text.trim(),
                    'logoUrl': logoController.text.trim(),
                    'isLocal': isLocalNotifier.value,
                  };
                  
                  final service = ref.read(firestoreServiceProvider);
                  if (club == null) {
                    await service.addClub(data);
                  } else {
                    await service.updateClub(club['id'], data);
                  }
                  
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteClub(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Eliminar Club'),
        content: const Text('¿Estás seguro de que deseas eliminar este club?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(firestoreServiceProvider).deleteClub(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(clubsStreamProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Gestión de Clubes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClubDialog(context),
        backgroundColor: context.colors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: clubsAsync.when(
        data: (clubs) {
          if (clubs.isEmpty) {
            return Center(
              child: Text(
                'No hay clubes registrados',
                style: context.typography.bodyLarge.copyWith(color: context.colors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: clubs.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: context.colors.border),
            itemBuilder: (context, index) {
              final club = clubs[index];
              return JNCard(
                padding: const EdgeInsets.all(12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: context.colors.surfaceLight,
                    backgroundImage: (club['logoUrl'] != null && club['logoUrl'].toString().isNotEmpty)
                        ? NetworkImage(club['logoUrl'])
                        : null,
                    child: (club['logoUrl'] == null || club['logoUrl'].toString().isEmpty)
                        ? Icon(Icons.shield, color: context.colors.textTertiary)
                        : null,
                  ),
                  title: Text(
                    club['name'] ?? 'Sin nombre',
                    style: context.typography.titleMedium,
                  ),
                  subtitle: club['isLocal'] == true
                      ? Text(
                          'Club Local',
                          style: context.typography.labelSmall.copyWith(color: context.colors.primary),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: context.colors.textSecondary),
                        onPressed: () => _showAddClubDialog(context, club),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: context.colors.error),
                        onPressed: () => _deleteClub(club['id']),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: (50 * index).ms).slideX();
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: TextStyle(color: context.colors.error)),
        ),
      ),
    );
  }
}