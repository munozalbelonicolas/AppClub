import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/services/firestore_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SponsorsManagementScreen extends ConsumerWidget {
  const SponsorsManagementScreen({super.key});

  static const List<Map<String, String>> _presetSponsors = [
    {
      'name': 'Banco Macro (Oficial)',
      'imageUrl': 'assets/images/sponsor_macro.png',
      'linkUrl': 'https://www.macro.com.ar',
    },
    {
      'name': 'Powerade (Hidratación)',
      'imageUrl': 'assets/images/sponsor_powerade.png',
      'linkUrl': 'https://www.powerade.com',
    },
    {
      'name': 'Adidas (Indumentaria)',
      'imageUrl': 'assets/images/sponsor_adidas.png',
      'linkUrl': 'https://www.adidas.com.ar',
    },
  ];

  void _showAddSponsorDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final imageUrlController = TextEditingController();
    final linkUrlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(color: AppColors.border, width: 0.5),
              ),
              title: Text('Añadir Sponsor', style: AppTypography.titleLarge),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: nameController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'Nombre del Sponsor',
                          labelText: 'Nombre',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ingresa el nombre'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: imageUrlController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'URL de la imagen (HTTPS)',
                          labelText: 'Imagen URL',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa la URL o ruta del recurso';
                          }
                          if (!value.startsWith('http') &&
                              !value.startsWith('assets/')) {
                            return 'Debe ser una URL válida o ruta de asset (assets/)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: linkUrlController,
                        style: AppTypography.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'URL de destino (opcional)',
                          labelText: 'Enlace web',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Preseteados rápidos:',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _presetSponsors.map((preset) {
                          return ActionChip(
                            label: Text(preset['name']!),
                            labelStyle: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                            ),
                            backgroundColor: AppColors.surfaceLight,
                            onPressed: () {
                              setDialogState(() {
                                nameController.text = preset['name']!;
                                imageUrlController.text = preset['imageUrl']!;
                                linkUrlController.text = preset['linkUrl']!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final firestoreService = ref.read(
                        firestoreServiceProvider,
                      );
                      await firestoreService.addSponsor({
                        'name': nameController.text.trim(),
                        'imageUrl': imageUrlController.text.trim(),
                        'linkUrl': linkUrlController.text.trim(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sponsor "${nameController.text}" añadido con éxito!',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sponsorsAsync = ref.watch(sponsorsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestión de Sponsors'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton:
          FloatingActionButton.extended(
            onPressed: () => _showAddSponsorDialog(context, ref),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Añadir Sponsor',
              style: TextStyle(color: Colors.white),
            ),
          ).animate().scale(
            delay: 200.ms,
            duration: 400.ms,
            curve: Curves.easeOutBack,
          ),
      body: sponsorsAsync.when(
        data: (sponsors) {
          if (sponsors.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.business,
                        size: 64,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No hay sponsors registrados',
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Añade patrocinadores oficiales del club para que se visualicen en el carrusel de la pantalla de inicio.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    JNButton(
                      label: 'Cargar Sponsors de Prueba',
                      onPressed: () async {
                        final firestoreService = ref.read(
                          firestoreServiceProvider,
                        );
                        for (final preset in _presetSponsors) {
                          await firestoreService.addSponsor(preset);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sponsors de prueba añadidos!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      size: JNButtonSize.medium,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: sponsors.length,
            itemBuilder: (context, index) {
              final sponsor = sponsors[index];
              return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: JNCard(
                      padding: EdgeInsets.zero,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(AppSpacing.radiusMd),
                              bottomLeft: Radius.circular(AppSpacing.radiusMd),
                            ),
                            child: _buildSponsorImage(
                              sponsor['imageUrl'] ?? '',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sponsor['name'] ?? 'Sponsor',
                                  style: AppTypography.titleMedium,
                                ),
                                if (sponsor['linkUrl'] != null &&
                                    sponsor['linkUrl']
                                        .toString()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    sponsor['linkUrl'],
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: const Text('Eliminar Sponsor'),
                                  content: Text(
                                    '¿Estás seguro de eliminar a ${sponsor['name']}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'Cancelar',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await ref
                                            .read(firestoreServiceProvider)
                                            .deleteSponsor(sponsor['id']);
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Sponsor ${sponsor['name']} eliminado',
                                              ),
                                              backgroundColor:
                                                  AppColors.warning,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text(
                                        'Eliminar',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  )
                  .animate(delay: (index * 50).ms)
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: 0.05);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error al cargar sponsors: $err')),
      ),
    );
  }
}

Widget _buildSponsorImage(String url) {
  if (url.startsWith('assets/')) {
    return Image.asset(url, width: 80, height: 80, fit: BoxFit.cover);
  }
  return CachedNetworkImage(
    imageUrl: url,
    width: 80,
    height: 80,
    fit: BoxFit.cover,
    placeholder: (context, url) => Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
    errorWidget: (context, url, error) => Container(
      color: AppColors.surfaceLight,
      child: const Icon(Icons.broken_image, size: 24),
    ),
  );
}
