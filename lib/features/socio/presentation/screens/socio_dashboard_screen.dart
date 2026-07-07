import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';

class SocioDashboardScreen extends ConsumerWidget {
  const SocioDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionUser = ref.watch(currentUserProvider);
    if (sessionUser == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          'Inicio',
          style: context.typography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Card
              JNCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, ${sessionUser.name}',
                      style: context.typography.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Bienvenido a tu portal de Socio',
                      style: context.typography.bodyLarge.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              Text(
                'Información del Club',
                style: context.typography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              
              JNCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 40,
                      color: context.colors.accent,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tienda Oficial',
                            style: context.typography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Encuentra merchandising y productos del club en la pestaña Tienda.',
                            style: context.typography.bodySmall.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              JNCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 40,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tu Carnet Digital',
                            style: context.typography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Usa tu carnet desde la aplicación para acceder a las instalaciones.',
                            style: context.typography.bodySmall.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
