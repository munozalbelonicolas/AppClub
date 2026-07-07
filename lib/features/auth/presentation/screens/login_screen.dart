import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';
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
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'too-many-requests') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cuenta bloqueada por múltiples intentos fallidos. Restablece tu contraseña o intenta más tarde.'),
              backgroundColor: context.colors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credenciales incorrectas o error de red.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas o error de red.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailController.text);
    
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogContext.colors.surface,
          title: const Text('Recuperar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                style: context.typography.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: context.typography.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancelar', style: TextStyle(color: dialogContext.colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: dialogContext.colors.primary),
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Por favor, ingresa un correo válido.')),
                  );
                  return;
                }
                
                Navigator.pop(dialogContext); // Close dialog
                setState(() => _isLoading = true);
                
                try {
                  final authService = ref.read(authServiceProvider);
                  await authService.sendPasswordResetEmail(email);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Se ha enviado un correo para restablecer tu contraseña.'),
                      backgroundColor: context.colors.success,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Ocurrió un error. Verifica que el correo esté registrado.'),
                      backgroundColor: context.colors.error,
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
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
                            color: context.colors.primary.withValues(alpha: 0.3),
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
                  style: context.typography.headlineLarge.copyWith(
                    letterSpacing: 3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 4),

              Center(
                child: Text(
                  'Iniciá sesión para continuar',
                  style: context.typography.bodyMedium,
                ),
              ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 36),

              const SizedBox(height: 28),

              // Email field
              TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: context.typography.bodyLarge,
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
                    style: context.typography.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: context.colors.textTertiary,
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
                  onPressed: _handleForgotPassword,
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: context.typography.bodySmall.copyWith(
                      color: context.colors.primary,
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
                  Expanded(child: Divider(color: context.colors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('o', style: context.typography.bodySmall),
                  ),
                  Expanded(child: Divider(color: context.colors.border)),
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
                    Text('¿No tenés cuenta? ', style: context.typography.bodyMedium),
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
                        style: context.typography.bodyMedium.copyWith(
                          color: context.colors.primary,
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
