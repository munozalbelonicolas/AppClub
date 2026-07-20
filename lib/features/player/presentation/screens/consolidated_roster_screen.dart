import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/category_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';

class ConsolidatedRosterScreen extends ConsumerStatefulWidget {
  const ConsolidatedRosterScreen({super.key});

  @override
  ConsumerState<ConsolidatedRosterScreen> createState() => _ConsolidatedRosterScreenState();
}

class _ConsolidatedRosterScreenState extends ConsumerState<ConsolidatedRosterScreen> {
  String? _selectedCategory;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isCoach = user.role == 'dt';
    final isAdmin = user.role == 'directivo' || user.role == 'secretario';

    // If coach, force category
    if (isCoach && _selectedCategory != user.category) {
      _selectedCategory = user.category;
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Consolidado de Jugadores', style: context.typography.titleLarge),
        backgroundColor: context.colors.surface,
        elevation: 0,
        actions: [
          if (_isExporting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.download, color: context.colors.primary),
              tooltip: 'Exportar a Excel',
              onPressed: () => _exportToExcel(isCoach ? user.category : _selectedCategory),
            ),
        ],
      ),
      body: Column(
        children: [
          if (isAdmin || isCoach)
            Container(
              color: context.colors.surface,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Consumer(
                builder: (context, ref, child) {
                  final categoriesAsync = ref.watch(categoriesStreamProvider);
                  return categoriesAsync.when(
                    data: (categories) {
                      List<String> displayCategories = categories;
                      if (isCoach) {
                        displayCategories = user.assignedCategories ?? [];
                        if (displayCategories.isEmpty && user.category != null) {
                          displayCategories = [user.category!];
                        }
                      }

                      return DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por Categoría',
                          prefixIcon: Icon(Icons.filter_list),
                        ),
                        items: [
                          if (isAdmin || (isCoach && displayCategories.length > 1))
                            DropdownMenuItem(value: null, child: Text(isCoach ? 'Mis categorías' : 'Todas las categorías')),
                          ...displayCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        },
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('Error al cargar categorías', style: TextStyle(color: context.colors.error)),
                  );
                },
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'jugador')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: TextStyle(color: context.colors.error)),
                  );
                }

                var docs = snapshot.data?.docs ?? [];
                
                // Filter by category if selected
                List<String>? allowedCategories;
                if (isCoach) {
                  allowedCategories = user.assignedCategories ?? [];
                  if (allowedCategories.isEmpty && user.category != null) {
                    allowedCategories = [user.category!];
                  }
                }

                if (_selectedCategory != null) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['category'] == _selectedCategory;
                  }).toList();
                } else if (isCoach && allowedCategories != null) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return allowedCategories!.contains(data['category']);
                  }).toList();
                }

                // Sort by category, then last name
                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  final catA = dataA['category'] as String? ?? '';
                  final catB = dataB['category'] as String? ?? '';
                  
                  final catCompare = catA.compareTo(catB);
                  if (catCompare != 0) return catCompare;

                  final lastA = (dataA['lastName'] as String? ?? '').toLowerCase();
                  final lastB = (dataB['lastName'] as String? ?? '').toLowerCase();
                  return lastA.compareTo(lastB);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Text('No hay jugadores registrados en esta categoría.', style: context.typography.bodyLarge),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final playerId = docs[index].id;
                    final name = data['name'] ?? '';
                    final lastName = data['lastName'] ?? '';
                    final category = data['category'] ?? 'Sin categoría';
                    final dni = data['dni'] ?? 'Sin DNI';
                    final quotaStatus = data['quotaStatus'] as String? ?? 'atrasado';
                    final isAlDia = quotaStatus == 'al_dia';
                    
                    return JNCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                          child: Icon(Icons.person, color: context.colors.primary),
                        ),
                        title: Text('$lastName, $name', style: context.typography.titleMedium),
                        subtitle: Text('Cat: $category • DNI: $dni', style: context.typography.bodySmall),
                        trailing: InkWell(
                          onTap: isAdmin ? () {
                            final newStatus = isAlDia ? 'atrasado' : 'al_dia';
                            ref.read(firestoreServiceProvider).updatePlayerQuotaStatus(playerId, newStatus);
                          } : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAlDia ? context.colors.success.withValues(alpha: 0.1) : context.colors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isAlDia ? context.colors.success : context.colors.error),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isAlDia ? 'AL DÍA' : 'ATRASADO',
                                  style: context.typography.labelSmall.copyWith(
                                    color: isAlDia ? context.colors.success : context.colors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit, size: 12, color: isAlDia ? context.colors.success : context.colors.error),
                                ],
                              ],
                            ),
                          ),
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

  Future<void> _exportToExcel(String? categoryFilter) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final user = ref.read(currentUserProvider);
      final isCoach = user?.role == 'dt';
      List<String>? allowedCategories;
      if (isCoach) {
        allowedCategories = user?.assignedCategories ?? [];
        if (allowedCategories.isEmpty && user?.category != null) {
          allowedCategories = [user!.category!];
        }
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'jugador')
          .get();

      var docs = querySnapshot.docs;
      
      if (categoryFilter != null) {
        docs = docs.where((doc) {
          final data = doc.data();
          return data['category'] == categoryFilter;
        }).toList();
      } else if (isCoach && allowedCategories != null) {
        docs = docs.where((doc) {
          final data = doc.data();
          return allowedCategories!.contains(data['category']);
        }).toList();
      }

      docs.sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();
        final catA = dataA['category'] as String? ?? '';
        final catB = dataB['category'] as String? ?? '';
        
        final catCompare = catA.compareTo(catB);
        if (catCompare != 0) return catCompare;

        final lastA = (dataA['lastName'] as String? ?? '').toLowerCase();
        final lastB = (dataB['lastName'] as String? ?? '').toLowerCase();
        return lastA.compareTo(lastB);
      });

      final excel = Excel.createExcel();
      final sheetObject = excel['Jugadores'];
      excel.setDefaultSheet('Jugadores');

      // Define headers
      final headers = [
        'Categoría',
        'Apellido',
        'Nombre',
        'DNI',
        'Fecha de Nacimiento',
        'Edad',
        'Peso',
        'Altura',
        'Estado',
        'Fecha Venc. Apto Físico'
      ];
      
      sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (var doc in docs) {
        final data = doc.data();
        
        String birthDateStr = '';
        if (data['birthDate'] != null) {
          final bd = (data['birthDate'] as Timestamp).toDate();
          birthDateStr = DateFormat('dd/MM/yyyy').format(bd);
        }

        String aptoStr = '';
        if (data['aptoFisicoExpiry'] != null) {
          final aptoDate = (data['aptoFisicoExpiry'] as Timestamp).toDate();
          aptoStr = DateFormat('dd/MM/yyyy').format(aptoDate);
        }

        final row = [
          TextCellValue(data['category']?.toString() ?? ''),
          TextCellValue(data['lastName']?.toString() ?? ''),
          TextCellValue(data['name']?.toString() ?? ''),
          TextCellValue(data['dni']?.toString() ?? ''),
          TextCellValue(birthDateStr),
          TextCellValue(data['age']?.toString() ?? ''),
          TextCellValue(data['weight']?.toString() ?? ''),
          TextCellValue(data['height']?.toString() ?? ''),
          TextCellValue(data['status']?.toString() ?? ''),
          TextCellValue(aptoStr),
        ];

        sheetObject.appendRow(row);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/jugadores_${categoryFilter ?? 'todos'}.xlsx';
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        if (mounted) {
          // ignore: deprecated_member_use
          await Share.shareXFiles([XFile(filePath)], text: 'Listado de Jugadores');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}
