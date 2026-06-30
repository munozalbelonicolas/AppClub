import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/services/auth_service.dart';

class VerifyEmailScreen extends ConsumerWidget {
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  const VerifyEmailScreen({
    super.key,
    required this.onRefresh,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
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
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Verificá tu correo',
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Te enviamos un enlace de verificación a tu correo electrónico. Por favor revisá tu bandeja de entrada o carpeta de spam y hacé clic en el enlace para continuar.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              JNButton(
                label: 'Ya lo verifiqué',
                onPressed: () async {
                  await ref.read(authServiceProvider).checkEmailVerified();
                  // Will force refresh of user session in AppNavigator
                  onRefresh();
                },
                fullWidth: true,
              ),
              const SizedBox(height: 16),
              JNButton(
                label: 'Reenviar correo',
                variant: JNButtonVariant.outline,
                onPressed: () async {
                  await ref.read(authServiceProvider).sendEmailVerification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Correo de verificación reenviado'),
                      ),
                    );
                  }
                },
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
