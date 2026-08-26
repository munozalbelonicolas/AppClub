import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/app_typography.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), widget.onFinished);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Club Logo / Emblem
                  Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.primary.withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_logo.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      .animate()
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.0, 1.0),
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 28),

                  // Club Name
                  Text(
                        'JORGE NEWBERY',
                        style: context.typography.displaySmall.copyWith(
                          letterSpacing: 4,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                      .animate(delay: 400.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 500.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 8),

                  Text(
                    'ASOC. DEPORTIVA INF. Y JUV.',
                    style: context.typography.labelMedium.copyWith(
                      letterSpacing: 2.5,
                      color: context.colors.textTertiary,
                    ),
                  ).animate(delay: 600.ms).fadeIn(duration: 500.ms),

                  const SizedBox(height: 48),

                  // Loading indicator
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(
                        context.colors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ).animate(delay: 800.ms).fadeIn(duration: 400.ms),
                ],
              ),
            ),

            // Powered by Nilotech footer (single line: logo + text)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/icons/LogoNilo.png',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Powered by Nilotech',
                    style: context.typography.labelSmall.copyWith(
                      color: context.colors.textSecondary,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ).animate(delay: 700.ms).fadeIn(duration: 500.ms),
            ),
          ],
        ),
      ),
    );
  }
}
