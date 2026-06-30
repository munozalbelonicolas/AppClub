import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';

import '../../../../core/services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Wait for provider update
      if (mounted) {
        widget.onLogin();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Credenciales incorrectas o error de red.')),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),

              // Logo
              Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/app_logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    duration: 500.ms,
                    curve: Curves.easeOut,
                  )
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  'JORGE NEWBERY',
                  style: AppTypography.headlineLarge.copyWith(
                    letterSpacing: 3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 4),

              Center(
                child: Text(
                  'Iniciá sesión para continuar',
                  style: AppTypography.bodyMedium,
                ),
              ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 36),

              const SizedBox(height: 28),

              // Email field
              TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTypography.bodyLarge,
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                  )
                  .animate(delay: 500.ms)
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: 0.05),

              const SizedBox(height: 14),

              // Password field
              TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  )
                  .animate(delay: 600.ms)
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: 0.05),

              const SizedBox(height: 10),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Login button
              JNButton(
                    label: 'Iniciar Sesión',
                    onPressed: _handleLogin,
                    fullWidth: true,
                    size: JNButtonSize.large,
                    isLoading: _isLoading,
                  )
                  .animate(delay: 700.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1),

              const SizedBox(height: 16),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('o', style: AppTypography.bodySmall),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),

              const SizedBox(height: 16),

              // Google sign in
              JNButton(
                label: 'Continuar con Google',
                onPressed: () async {
                  setState(() => _isLoading = true);
                  final authService = ref.read(authServiceProvider);
                  final session = await authService.signInWithGoogle(context);
                  setState(() => _isLoading = false);
                  if (session != null) {
                    widget.onLogin();
                  }
                },
                variant: JNButtonVariant.outline,
                fullWidth: true,
                icon: Icons.g_mobiledata_rounded,
              ),

              const SizedBox(height: 24),

              // Register link
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('¿No tenés cuenta? ', style: AppTypography.bodyMedium),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(
                              onRegisterSuccess: () {
                                Navigator.pop(context);
                                widget.onLogin();
                              },
                              onBackToLogin: () => Navigator.pop(context),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Registrate',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
