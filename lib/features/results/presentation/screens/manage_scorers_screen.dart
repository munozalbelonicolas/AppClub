import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/widgets/jn_card.dart';

class ManageScorersScreen extends ConsumerStatefulWidget {
  const ManageScorersScreen({super.key});

  @override
  ConsumerState<ManageScorersScreen> createState() => _ManageScorersScreenState();
}

class _ManageScorersScreenState extends ConsumerState<ManageScorersScreen> {
  String _selectedCategory = 'Primera';


  void _showAddEditScorerDialog(BuildContext context, [Map<String, dynamic>? scorer]) {
    final isEditing = scorer != null;
    final nameController = TextEditingController(text: isEditing ? scorer['name'] : '');
    final teamController = TextEditingController(text: isEditing ? scorer['team'] : 'Club Local');
    final goalsController = TextEditingController(text: isEditing ? scorer['goals'].toString() : '0');
    final isClubNotifier = ValueNotifier<bool>(isEditing ? (scorer['isClub'] ?? false) : true);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text(
            isEditing ? 'Editar Goleador' : 'Nuevo Goleador',
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
                    decoration: const InputDecoration(labelText: 'Nombre del Jugador'),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Ingresa el nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: teamController,
                    decoration: const InputDecoration(labelText: 'Equipo'),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Ingresa el equipo' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: goalsController,
                    decoration: const InputDecoration(labelText: 'Goles'),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Ingresa la cantidad';
                      if (int.tryParse(val.trim()) == null) return 'Debe ser un número válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: isClubNotifier,
                    builder: (context, isClub, child) {
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('¿Es de nuestro Club?'),
                        value: isClub,
                        activeThumbColor: context.colors.primary,
                        onChanged: (val) {
                          isClubNotifier.value = val;
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
                    'team': teamController.text.trim(),
                    'goals': int.parse(goalsController.text.trim()),
                    'isClub': isClubNotifier.value,
                    'category': _selectedCategory,
                  };
                  
                  final service = ref.read(firestoreServiceProvider);
                  if (isEditing) {
                    await service.updateScorer(scorer['id'], data);
                  } else {
                    await service.addScorer(data);
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

  Future<void> _deleteScorer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Eliminar Goleador'),
        content: const Text('¿Estás seguro de que deseas eliminar a este goleador?'),
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
      await ref.read(firestoreServiceProvider).deleteScorer(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(appCategoriesProvider);
    if (!categories.contains(_selectedCategory) && categories.isNotEmpty) {
      // Must schedule setState because we are building
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedCategory = categories.first;
        });
      });
    }

    final scorersAsync = ref.watch(scorersStreamProvider(_selectedCategory));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Gestión de Goleadores'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditScorerDialog(context),
        backgroundColor: context.colors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Category Selector
          Container(
            color: context.colors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.category, color: context.colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: categories.contains(_selectedCategory) ? _selectedCategory : null,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: scorersAsync.when(
              data: (scorers) {
                if (scorers.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay goleadores en esta categoría',
                      style: context.typography.bodyLarge.copyWith(color: context.colors.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: scorers.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: context.colors.border),
                  itemBuilder: (context, index) {
                    final scorer = scorers[index];
                    final isClub = scorer['isClub'] ?? false;
                    
                    return JNCard(
                      padding: const EdgeInsets.all(12),
                      color: isClub ? context.colors.primary.withValues(alpha: 0.05) : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isClub ? context.colors.primary : context.colors.surfaceLight,
                          child: Text(
                            '${index + 1}',
                            style: context.typography.titleMedium.copyWith(
                              color: isClub ? Colors.white : context.colors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          scorer['name'] ?? 'Sin nombre',
                          style: context.typography.titleMedium,
                        ),
                        subtitle: Text(
                          scorer['team'] ?? 'Sin equipo',
                          style: context.typography.bodySmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${scorer['goals']}',
                                style: context.typography.titleLarge.copyWith(color: context.colors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: context.colors.textSecondary),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showAddEditScorerDialog(context, scorer);
                                } else if (val == 'delete') {
                                  _deleteScorer(scorer['id']);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Editar'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 20, color: context.colors.error),
                                      const SizedBox(width: 8),
                                      Text('Eliminar', style: TextStyle(color: context.colors.error)),
                                    ],
                                  ),
                                ),
                              ],
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
          ),
        ],
      ),
    );
  }
}