import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
      backgroundColor: AppColors.background,
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
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
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
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
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
                  style: AppTypography.titleMedium,
                ),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () {
                    ref.read(firestoreServiceProvider).deleteLeagueReport(report['id']);
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(dateStr, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 12),
          Text(report['description'] ?? '', style: AppTypography.bodyMedium),
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
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        report['fileName'],
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.download, size: 20, color: AppColors.textSecondary),
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
              backgroundColor: AppColors.surface,
              title: Text('Nuevo Informe', style: AppTypography.titleLarge),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Título'),
                      style: AppTypography.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Descripción'),
                      maxLines: 3,
                      style: AppTypography.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
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
                                    style: AppTypography.bodyMedium,
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
                  child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
