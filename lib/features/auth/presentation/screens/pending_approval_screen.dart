import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';

class PendingApprovalScreen extends ConsumerWidget {
  final VoidCallback onSignOut;
  final VoidCallback onRefresh;

  const PendingApprovalScreen({
    super.key,
    required this.onSignOut,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: context.colors.error),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              onSignOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 80,
                color: context.colors.warning,
              ),
              const SizedBox(height: 24),
              Text(
                'Cuenta en revisión',
                textAlign: TextAlign.center,
                style: context.typography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: context.colors.warning.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Tu cuenta se encuentra pendiente de aprobación por parte del Club. Recibirás una notificación cuando sea aprobada.',
                  textAlign: TextAlign.center,
                  style: context.typography.bodyLarge.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar estado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.surfaceLight,
                  foregroundColor: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}