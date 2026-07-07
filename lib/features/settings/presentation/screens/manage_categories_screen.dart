import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/category_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Gestionar Categorías', style: context.typography.titleLarge),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Text(
                'No hay categorías creadas.',
                style: context.typography.bodyLarge,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final category = categories[index];
              return JNCard(
                child: ListTile(
                  title: Text(category, style: context.typography.titleMedium),
                  leading: CircleAvatar(
                    backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.category, color: context.colors.primary),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: context.colors.error),
                    onPressed: () => _confirmDelete(context, ref, category),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error al cargar categorías: $err',
              style: context.typography.bodyMedium.copyWith(color: context.colors.error)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Categoría'),
        backgroundColor: context.colors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('Nueva Categoría', style: context.typography.titleLarge),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Nombre de Categoría (Ej: 2021)'),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'El nombre es requerido';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final service = ref.read(categoryServiceProvider);
                  await service.addCategory(controller.text.trim());
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String categoryName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('Eliminar Categoría', style: context.typography.titleLarge),
          content: Text('¿Seguro que deseas eliminar la categoría $categoryName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final service = ref.read(categoryServiceProvider);
                await service.deleteCategory(categoryName);
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.error),
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
