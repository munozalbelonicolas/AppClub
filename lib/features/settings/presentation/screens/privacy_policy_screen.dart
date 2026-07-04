import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/widgets/legal_text_screen.dart';
import 'legal_texts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalTextScreen(
      appBarTitle: 'Política de Privacidad',
      headerTitle: 'Seguridad y Confianza',
      headerSubtitle: 'Tu privacidad es nuestra prioridad en AppClub.',
      headerIcon: Icons.shield_outlined,
      accentColorBuilder: (ctx) => ctx.colors.primary,
      legalText: LegalTexts.privacyPolicy,
    );
  }
}