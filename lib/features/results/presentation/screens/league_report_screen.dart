import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import 'document_viewer_screen.dart';

class LeagueReportScreen extends ConsumerStatefulWidget {
  const LeagueReportScreen({super.key});

  @override
  ConsumerState<LeagueReportScreen> createState() => _LeagueReportScreenState();
}

class _LeagueReportScreenState extends ConsumerState<LeagueReportScreen> {
  @override
  Widget build(BuildContext context) {
    final sessionUser = ref.watch(currentUserProvider)!;
    final reportsAsync = ref.watch(leagueReportsStreamProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Informes de Liga'),
        actions: [
          if (sessionUser.isAdmin || sessionUser.role == 'dt')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddReportDialog(context),
            ),
        ],
      ),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Text(
                'No hay informes de liga.',
                style: context.typography.bodyMedium.copyWith(color: context.colors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportCard(report, sessionUser.isAdmin);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: context.colors.error))),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isAdmin) {
    final createdAt = report['createdAt'] as Timestamp?;
    final dateStr = createdAt != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate())
        : '';
        
    return JNCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  report['title'] ?? 'Sin Título',
                  style: context.typography.titleMedium,
                ),
              ),
              if (isAdmin)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: context.colors.error),
                  onPressed: () {
                    ref.read(firestoreServiceProvider).deleteLeagueReport(report['id']);
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(dateStr, style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary)),
          const SizedBox(height: 12),
          Text(report['description'] ?? '', style: context.typography.bodyMedium),
          const SizedBox(height: 16),
          if (report['fileName'] != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentViewerScreen(
                      title: report['title'] ?? 'Informe',
                      fileName: report['fileName'] ?? 'Documento',
                      fileUrl: report['fileUrl'] as String?,
                      previewUrl: report['previewUrl'] as String?,
                      format: report['format'] as String?,
                      pageCount: (report['pageCount'] as int?) ?? 1,
                      publicId: report['publicId'] as String?,
                      version: report['version']?.toString(),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      (report['fileName'] as String).toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf
                          : ((report['fileName'] as String).toLowerCase().endsWith('.jpg') ||
                                  (report['fileName'] as String).toLowerCase().endsWith('.png') ||
                                  (report['fileName'] as String).toLowerCase().endsWith('.jpeg'))
                              ? Icons.image
                              : Icons.description,
                      color: (report['fileName'] as String).toLowerCase().endsWith('.pdf')
                          ? context.colors.error
                          : context.colors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report['fileName'],
                            style: context.typography.bodyMedium.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Toca para visualizar',
                            style: context.typography.bodySmall.copyWith(
                              color: context.colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.visibility_outlined, size: 20, color: context.colors.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddReportDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    PlatformFile? selectedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              title: Text('Nuevo Informe', style: context.typography.titleLarge),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      enabled: !isUploading,
                      decoration: const InputDecoration(labelText: 'Título'),
                      style: context.typography.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      enabled: !isUploading,
                      decoration: const InputDecoration(labelText: 'Descripción'),
                      maxLines: 3,
                      style: context.typography.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selectedFile != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.attach_file, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedFile!.name,
                                    style: context.typography.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isUploading)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () {
                                      setDialogState(() {
                                        selectedFile = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ] else ...[
                            TextButton.icon(
                              onPressed: isUploading
                                  ? null
                                  : () async {
                                      final result = await FilePicker.pickFiles(
                                        type: FileType.custom,
                                        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
                                      );
                                      if (result != null) {
                                        setDialogState(() {
                                          selectedFile = result.files.first;
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Adjuntar Archivo'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isUploading) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Subiendo documento... por favor espera.',
                              style: context.typography.bodySmall.copyWith(
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
                  onPressed: isUploading
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('El título es obligatorio.')),
                            );
                            return;
                          }

                          setDialogState(() => isUploading = true);

                          try {
                            String? fileUrl;
                            String? previewUrl;
                            String? format;
                            int pageCount = 1;
                            String? publicId;
                            String? version;

                            if (selectedFile != null) {
                              final File fileToUpload;
                              if (selectedFile!.path != null) {
                                fileToUpload = File(selectedFile!.path!);
                              } else {
                                final bytes = await selectedFile!.readAsBytes();
                                final tempDir = await getTemporaryDirectory();
                                fileToUpload = File('${tempDir.path}/${selectedFile!.name}');
                                await fileToUpload.writeAsBytes(bytes);
                              }

                              final uploadResult = await ImageUploadService.uploadDocument(
                                fileToUpload,
                                originalFileName: selectedFile!.name,
                              );
                                fileUrl = uploadResult['fileUrl'] as String?;
                                previewUrl = uploadResult['previewUrl'] as String?;
                                format = uploadResult['format'] as String?;
                                pageCount = (uploadResult['pageCount'] as int?) ?? 1;
                                publicId = uploadResult['publicId'] as String?;
                                version = uploadResult['version'] as String?;
                              }

                            final currentUser = ref.read(currentUserProvider);
                            await ref.read(firestoreServiceProvider).addLeagueReport({
                              'title': title,
                              'description': descController.text.trim(),
                              'fileUrl': fileUrl,
                              'fileName': selectedFile?.name,
                              'previewUrl': previewUrl,
                              'format': format,
                              'pageCount': pageCount,
                              'publicId': publicId,
                              'version': version,
                              'authorId': currentUser?.id ?? '',
                            });

                            // Notificación Push a todos los usuarios del club
                            await NotificationService().sendNotification(
                              title: '📄 Nuevo Informe de Liga',
                              body: 'Se ha publicado un nuevo informe oficial: "$title". Ya disponible para consultar en la app.',
                              authorId: currentUser?.id ?? '',
                              targetCategory: 'all',
                              data: {
                                'type': 'league_report',
                                'title': title,
                              },
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Informe guardado correctamente.')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isUploading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al subir informe: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Subir'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}