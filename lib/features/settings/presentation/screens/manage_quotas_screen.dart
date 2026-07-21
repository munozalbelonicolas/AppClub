import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';

class ManageQuotasScreen extends ConsumerStatefulWidget {
  const ManageQuotasScreen({super.key});

  @override
  ConsumerState<ManageQuotasScreen> createState() => _ManageQuotasScreenState();
}

class _ManageQuotasScreenState extends ConsumerState<ManageQuotasScreen> {
  String _selectedCategory = 'Todas';
  String _selectedStatus = 'Todos';

  List<String> _calculateMissingMonths(List<String> paidQuotas) {
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;
    
    final missingMonths = <String>[];
    final monthNames = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];

    for (int i = 1; i <= currentMonth; i++) {
      final monthStr = '$i'.padLeft(2, '0');
      final quotaStr = '$monthStr/$currentYear';
      if (!paidQuotas.contains(quotaStr)) {
        missingMonths.add(monthNames[i - 1]);
      }
    }
    return missingMonths;
  }

  void _showEditQuotasDialog(Map<String, dynamic> player) {
    final currentYear = DateTime.now().year;
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    
    List<String> currentPaidQuotas = List<String>.from(player['paidQuotas'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: context.colors.surface,
              title: Text('Cuotas de ${player['name']}', style: context.typography.titleLarge),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final monthStr = '${index + 1}'.padLeft(2, '0');
                    final quotaMonth = '$monthStr/$currentYear';
                    final isPaid = currentPaidQuotas.contains(quotaMonth);

                    return CheckboxListTile(
                      title: Text('${months[index]} $currentYear'),
                      value: isPaid,
                      activeColor: context.colors.primary,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            currentPaidQuotas.add(quotaMonth);
                          } else {
                            currentPaidQuotas.remove(quotaMonth);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(player['id']).update({
                        'paidQuotas': currentPaidQuotas,
                        'quotaStatus': _calculateMissingMonths(currentPaidQuotas).isEmpty ? 'al_dia' : 'atrasado',
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: const Text('Cuotas actualizadas'), backgroundColor: context.colors.success),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: context.colors.error),
                        );
                      }
                    }
                  },
                  child: Text('Guardar', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersStreamProvider);
    final categories = ref.watch(appCategoriesProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Estado de Cuotas'),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: context.colors.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Categoría:', style: context.typography.titleSmall),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                          ...categories.map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Estado:', style: context.typography.titleSmall),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                          DropdownMenuItem(value: 'Al Día', child: Text('Al Día')),
                          DropdownMenuItem(value: 'Deudor', child: Text('Deudor')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: playersAsync.when(
              data: (players) {
                // Filter by category and status
                final filteredPlayers = players.where((p) {
                  // Category Filter
                  if (_selectedCategory != 'Todas' && p['category'] != _selectedCategory) {
                    return false;
                  }
                  
                  // Status Filter
                  final paidQuotas = List<String>.from(p['paidQuotas'] ?? []);
                  final missing = _calculateMissingMonths(paidQuotas);
                  final isAlDia = missing.isEmpty;
                  
                  if (_selectedStatus == 'Al Día' && !isAlDia) return false;
                  if (_selectedStatus == 'Deudor' && isAlDia) return false;
                  
                  return true;
                }).toList();

                if (filteredPlayers.isEmpty) {
                  return const Center(child: Text('No hay jugadores que coincidan con los filtros'));
                }

                // Sort by name
                filteredPlayers.sort((a, b) => 
                  (a['name']?.toString() ?? '').toLowerCase().compareTo(
                    (b['name']?.toString() ?? '').toLowerCase()
                  )
                );

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filteredPlayers.length,
                  itemBuilder: (context, index) {
                    final p = filteredPlayers[index];
                    final paidQuotas = List<String>.from(p['paidQuotas'] ?? []);
                    final missingMonths = _calculateMissingMonths(paidQuotas);
                    final isAlDia = missingMonths.isEmpty;
                    
                    final badgeText = isAlDia ? 'AL DÍA' : 'DEUDOR';
                    final debtText = isAlDia ? '' : 'Debe: ${missingMonths.join(", ")}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: JNCard(
                        onTap: () => _showEditQuotasDialog(p),
                        padding: const EdgeInsets.all(12),
                        border: Border.all(
                          color: isAlDia 
                            ? context.colors.success.withValues(alpha: 0.3) 
                            : context.colors.error.withValues(alpha: 0.3),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                              child: Icon(Icons.person, color: context.colors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${p['name']} ${p['lastName']}', style: context.typography.titleMedium),
                                  Text('Cat: ${p['category'] ?? "Sin categoría"}', style: context.typography.bodySmall),
                                  if (!isAlDia)
                                    Text(
                                      debtText, 
                                      style: context.typography.bodySmall.copyWith(
                                        color: context.colors.error, 
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAlDia 
                                  ? context.colors.success.withValues(alpha: 0.1) 
                                  : context.colors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                badgeText,
                                style: context.typography.labelSmall.copyWith(
                                  color: isAlDia ? context.colors.success : context.colors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
