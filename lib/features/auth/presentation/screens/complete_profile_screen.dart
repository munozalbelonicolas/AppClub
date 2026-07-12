import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
import '../../../settings/presentation/screens/terms_conditions_screen.dart';

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
    if (!_formKey.currentState!.validate()) return;

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Debes aceptar los Términos y Condiciones para continuar.',
          ),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final session = ref.read(currentUserProvider);
      
      await authService.completeRegistration(
        phone1: session?.role == 'jugador' ? null : _phone1Controller.text.trim(),
        phone2: session?.role == 'jugador' || _phone2Controller.text.trim().isEmpty
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: Icon(Icons.logout, color: context.colors.textSecondary),
            label: Text(
              'Salir',
              style: context.typography.bodySmall.copyWith(
                  color: context.colors.textSecondary),
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
                  style: context.typography.headlineLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session?.role == 'jugador'
                      ? 'Debes aceptar los términos y condiciones y el reglamento del club para continuar.'
                      : 'Faltan algunos datos para finalizar tu registro con Google.',
                  style: context.typography.bodyMedium,
                ),
                const SizedBox(height: 32),
                
                // Read-only fields from Google
                TextFormField(
                  initialValue: '${session?.name} ${session?.lastName}',
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Nombre y Apellido',
                    labelStyle: context.typography.bodyMedium.copyWith(
                        color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.surfaceLight,
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
                    labelStyle: context.typography.bodyMedium.copyWith(
                        color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Contact Details (Only for non-players)
                if (session?.role != 'jugador') ...[
                  Text(
                    'Datos de contacto',
                    style: context.typography.labelMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone1Controller,
                    decoration: InputDecoration(
                      labelText: 'Teléfono principal',
                      hintText: 'Ej. 11 1234 5678',
                      labelStyle: context.typography.bodyMedium.copyWith(
                          color: context.colors.textSecondary),
                      filled: true,
                      fillColor: context.colors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      if (value.length != 10) return 'El teléfono debe tener 10 dígitos';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone2Controller,
                    decoration: InputDecoration(
                      labelText: 'Teléfono secundario (opcional)',
                      hintText: 'Ej. 11 1234 5678',
                      labelStyle: context.typography.bodyMedium.copyWith(
                          color: context.colors.textSecondary),
                      filled: true,
                      fillColor: context.colors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value != null && value.isNotEmpty && value.length != 10) {
                        return 'El teléfono debe tener 10 dígitos';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                ],

                // Terms
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _termsAccepted,
                        onChanged: (v) =>
                            setState(() => _termsAccepted = v ?? false),
                        activeColor: context.colors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TermsConditionsScreen(),
                            ),
                          );
                        },
                        child: Text.rich(
                          TextSpan(
                            text: 'He leído y acepto los ',
                            style: context.typography.bodySmall,
                            children: [
                              TextSpan(
                                text: 'Términos y Condiciones.',
                                style: context.typography.bodySmall.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Submit button
                JNButton(
                  label: 'Finalizar Registro',
                  onPressed: _handleComplete,
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