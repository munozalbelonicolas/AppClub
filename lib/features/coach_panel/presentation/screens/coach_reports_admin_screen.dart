import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';
import '../../../../core/widgets/jn_badge.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../results/presentation/screens/document_viewer_screen.dart';

class CoachReportsAdminScreen extends ConsumerStatefulWidget {
  const CoachReportsAdminScreen({super.key});

  @override
  ConsumerState<CoachReportsAdminScreen> createState() => _CoachReportsAdminScreenState();
}

class _CoachReportsAdminScreenState extends ConsumerState<CoachReportsAdminScreen> {
  String _selectedCategoryFilter = 'Todas';

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Future<void> _toggleReviewed(String reportId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('coach_reports').doc(reportId).update({
        'reviewed': !currentStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar estado: $e')),
        );
      }
    }
  }

  Future<void> _deleteReport(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Eliminar Informe'),
        content: const Text('¿Estás seguro de que deseas eliminar este informe? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(firestoreServiceProvider).deleteCoachReport(reportId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Informe eliminado correctamente.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar informe: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(coachReportsStreamProvider);
    final appCategories = ref.watch(appCategoriesProvider);
    final categories = ['Todas', ...appCategories];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Informes de Entrenadores'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ─── Filter by Category ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: context.colors.surface,
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 20, color: context.colors.textSecondary),
                const SizedBox(width: 8),
                Text('Categoría:', style: context.typography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: categories.contains(_selectedCategoryFilter) ? _selectedCategoryFilter : 'Todas',
                      isDense: true,
                      isExpanded: true,
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat == 'Todas' ? 'Todas las categorías' : 'Categoría $cat'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategoryFilter = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ─── Reports List ───
          Expanded(
            child: reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error al cargar informes: $err', style: TextStyle(color: context.colors.error)),
                ),
              ),
              data: (allReports) {
                final reports = _selectedCategoryFilter == 'Todas'
                    ? allReports
                    : allReports.where((r) {
                        final cat = (r['category'] ?? '').toString().trim();
                        return cat.toLowerCase() == _selectedCategoryFilter.toLowerCase() ||
                            cat.contains(_selectedCategoryFilter);
                      }).toList();

                if (reports.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 64, color: context.colors.textTertiary),
                          const SizedBox(height: 16),
                          Text(
                            'No hay informes cargados',
                            style: context.typography.titleMedium.copyWith(color: context.colors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedCategoryFilter == 'Todas'
                                ? 'Los informes y novedades enviados por los DTs aparecerán aquí.'
                                : 'No se encontraron informes para la categoría $_selectedCategoryFilter.',
                            textAlign: TextAlign.center,
                            style: context.typography.bodySmall.copyWith(color: context.colors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final reportId = report['id'] as String;
                    final title = report['title']?.toString() ?? 'Sin título';
                    final description = report['description']?.toString() ?? '';
                    final coachName = report['coachName']?.toString() ?? 'Entrenador';
                    final category = report['category']?.toString() ?? '';
                    final dateStr = _formatDate(report['createdAt']);
                    final attachmentUrl = report['attachmentUrl']?.toString();
                    final isReviewed = report['reviewed'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14.0),
                      child: JNCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Coach info, category, and date
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                JNAvatar(name: coachName, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        coachName,
                                        style: context.typography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        children: [
                                          if (category.isNotEmpty) ...[
                                            Text(
                                              'Cat. $category',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.colors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text('·', style: TextStyle(color: Colors.grey)),
                                            const SizedBox(width: 6),
                                          ],
                                          if (dateStr.isNotEmpty)
                                            Text(
                                              dateStr,
                                              style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 20, color: context.colors.error),
                                  tooltip: 'Eliminar informe',
                                  onPressed: () => _deleteReport(reportId),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Title & Reviewed Badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: context.typography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _toggleReviewed(reportId, isReviewed),
                                  borderRadius: BorderRadius.circular(12),
                                  child: JNBadge(
                                    label: isReviewed ? 'REVISADO' : 'PENDIENTE',
                                    type: isReviewed ? JNBadgeType.success : JNBadgeType.warning,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Description
                            Text(
                              description,
                              style: context.typography.bodyMedium.copyWith(
                                color: context.colors.textPrimary,
                                height: 1.4,
                              ),
                            ),

                            // Attachment thumbnail (if present)
                            if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DocumentViewerScreen(
                                        title: 'Adjunto: $title',
                                        fileName: 'adjunto_informe',
                                        fileUrl: attachmentUrl,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: context.colors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: context.colors.primary.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.attach_file, size: 18, color: context.colors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Ver archivo adjunto',
                                        style: TextStyle(
                                          color: context.colors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.open_in_new, size: 14, color: context.colors.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 8),

                            // Action footer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _toggleReviewed(reportId, isReviewed),
                                  icon: Icon(
                                    isReviewed ? Icons.undo : Icons.check_circle_outline,
                                    size: 16,
                                    color: isReviewed ? context.colors.textSecondary : context.colors.success,
                                  ),
                                  label: Text(
                                    isReviewed ? 'Marcar como pendiente' : 'Marcar como revisado',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isReviewed ? context.colors.textSecondary : context.colors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
