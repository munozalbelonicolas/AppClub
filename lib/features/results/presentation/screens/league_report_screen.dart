import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';

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
          if (report['fileName'] != null)
            InkWell(
              onTap: () async {
                final url = report['fileUrl'];
                if (url != null && await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                }
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
                    Icon(Icons.picture_as_pdf, color: context.colors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        report['fileName'],
                        style: context.typography.bodyMedium.copyWith(
                          color: context.colors.primary,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.download, size: 20, color: context.colors.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddReportDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    PlatformFile? selectedFile;

    showDialog(
      context: context,
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
                      decoration: const InputDecoration(labelText: 'Título'),
                      style: context.typography.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
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
                              onPressed: () async {
                                final result = await FilePicker.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf', 'doc', 'docx'],
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
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
                  onPressed: () async {
                    if (titleController.text.isNotEmpty) {
                      // Mock upload for now
                      final fileUrl = selectedFile != null ? 'https://example.com/${selectedFile!.name}' : null;
                      final fileName = selectedFile?.name;

                      await ref.read(firestoreServiceProvider).addLeagueReport({
                        'title': titleController.text.trim(),
                        'description': descController.text.trim(),
                        'fileUrl': fileUrl,
                        'fileName': fileName,
                        'authorId': ref.read(currentUserProvider)!.id,
                      });
                      if (context.mounted) Navigator.pop(context);
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