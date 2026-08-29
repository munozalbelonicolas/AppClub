import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/app_logger.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';

/// Banner de Redes Sociales del Club con fondo en tonos rojos oscuros, borde amarillo sutil y logos oficiales
class ClubSocialBanner extends StatelessWidget {
  const ClubSocialBanner({super.key});

  static const String _facebookUrl =
      'https://www.facebook.com/jorge.newbery.9822?rdid=vE3dEjqvpGhBjO0D&share_url=https%3A%2F%2Fwww.facebook.com%2Fshare%2F189DmSCr11%2F#';
  static const String _tiktokUrl =
      'https://www.tiktok.com/@jorgenewbery2026?_r=1&_t=ZS-99IOChrQFJH';
  static const String _instagramUrl =
      'https://www.instagram.com/asoc.deportivajorgenewbery/';

  Future<void> _openSocialUrl(BuildContext context, String urlString, String networkName) async {
    try {
      HapticFeedback.lightImpact();
      final uri = Uri.parse(urlString);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir $networkName'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error opening social URL: $urlString', error: e, tag: 'ClubSocialBanner');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar con $networkName'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  // Official SVG vector paths
  static const String _tiktokSvg = '''<svg viewBox="0 0 24 24" width="26" height="26" fill="currentColor">
    <path d="M19.589 6.686a4.793 4.793 0 0 1-3.77-4.245V2h-3.445v13.672a2.896 2.896 0 0 1-2.891 2.884 2.896 2.896 0 0 1-2.892-2.884 2.896 2.896 0 0 1 2.892-2.885c.484 0 .937.1 1.353.28v-3.56a6.438 6.438 0 0 0-1.353-.143c-3.585 0-6.491 2.906-6.491 6.491s2.906 6.491 6.491 6.491c3.585 0 6.49-2.906 6.49-6.491V8.697a8.21 8.21 0 0 0 4.816 1.554V6.806c-.352 0-.698-.04-1.034-.12z"/>
  </svg>''';

  static const String _instagramSvg = '''<svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">
    <rect x="2" y="2" width="20" height="20" rx="5.5" ry="5.5"/>
    <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/>
    <line x1="17.5" y1="6.5" x2="17.51" y2="6.5"/>
  </svg>''';

  static const String _facebookSvg = '''<svg viewBox="0 0 24 24" width="26" height="26" fill="currentColor">
    <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
  </svg>''';

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFFFD000);
    const goldSoftColor = Color(0xFFFFE082);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        // Borde fino del mismo tamaño que el cuadro de próximo partido
        border: Border.all(
          color: goldColor.withValues(alpha: 0.6),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF280B0B),
            Color(0xFF141414),
            Color(0xFF200909),
            Color(0xFF111111),
          ],
          stops: [0.0, 0.45, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: const Color(0xFFC00000).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          children: [
            // Resplandor sutil rojo y dorado de fondo
            Positioned(
              top: -15,
              right: -15,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goldColor.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -15,
              left: -15,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC00000).withValues(alpha: 0.18),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabecera elegante y amigable: Escudo + "Nuestras Redes"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: goldColor.withValues(alpha: 0.7),
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.sports_soccer,
                              size: 14,
                              color: goldColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nuestras Redes',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: goldSoftColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Fila de botones de redes sociales (TikTok, Instagram, Facebook)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // TikTok
                      _SocialIconButton(
                        tooltip: 'TikTok',
                        svgData: _tiktokSvg,
                        goldColor: goldColor,
                        onTap: () => _openSocialUrl(context, _tiktokUrl, 'TikTok'),
                      ),

                      // Instagram
                      _SocialIconButton(
                        tooltip: 'Instagram',
                        svgData: _instagramSvg,
                        goldColor: goldColor,
                        onTap: () => _openSocialUrl(context, _instagramUrl, 'Instagram'),
                      ),

                      // Facebook
                      _SocialIconButton(
                        tooltip: 'Facebook',
                        svgData: _facebookSvg,
                        goldColor: goldColor,
                        onTap: () => _openSocialUrl(context, _facebookUrl, 'Facebook'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, duration: 400.ms, curve: Curves.easeOut);
  }
}

class _SocialIconButton extends StatefulWidget {
  final String tooltip;
  final String svgData;
  final Color goldColor;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.tooltip,
    required this.svgData,
    required this.goldColor,
    required this.onTap,
  });

  @override
  State<_SocialIconButton> createState() => _SocialIconButtonState();
}

class _SocialIconButtonState extends State<_SocialIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 56,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: _isPressed ? 0.08 : 0.04),
              border: Border.all(
                color: widget.goldColor.withValues(alpha: _isPressed ? 0.5 : 0.2),
              ),
            ),
            child: Center(
              child: SvgPicture.string(
                widget.svgData,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  widget.goldColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
