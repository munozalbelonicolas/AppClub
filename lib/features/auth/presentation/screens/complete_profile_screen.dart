import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/providers/session_provider.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSignOut;

  const CompleteProfileScreen({
    super.key,
    required this.onComplete,
    required this.onSignOut,
  });

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();

  bool _termsAccepted = false;
  bool _isLoading = false;

  Future<void> _handleComplete() async {
    if (!_formKey.currentState!.validate() || !_termsAccepted) return;

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.completeRegistration(
        phone1: _phone1Controller.text.trim(),
        phone2: _phone2Controller.text.trim().isEmpty
            ? null
            : _phone2Controller.text.trim(),
      );

      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al completar registro: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            label: Text(
              'Salir',
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary),
            ),
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Completá tu perfil',
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Faltan algunos datos para finalizar tu registro con Google.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 32),
                
                // Read-only fields from Google
                TextFormField(
                  initialValue: '${session?.name} ${session?.lastName}',
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Nombre y Apellido',
                    labelStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: session?.email,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    labelStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Contact Details
                Text(
                  'Datos de contacto',
                  style: AppTypography.labelMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone1Controller,
                  decoration: InputDecoration(
                    labelText: 'Teléfono principal',
                    hintText: 'Ej. 11 1234 5678',
                    labelStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone2Controller,
                  decoration: InputDecoration(
                    labelText: 'Teléfono secundario (opcional)',
                    hintText: 'Ej. 11 1234 5678',
                    labelStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 32),

                // Terms
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _termsAccepted,
                        onChanged: (v) =>
                            setState(() => _termsAccepted = v ?? false),
                        activeColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Acepto los términos y condiciones y el reglamento del club',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Submit button
                JNButton(
                  label: 'Finalizar Registro',
                  onPressed: _termsAccepted ? _handleComplete : null,
                  isLoading: _isLoading,
                  fullWidth: true,
                  size: JNButtonSize.large,
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
