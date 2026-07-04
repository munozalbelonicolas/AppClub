import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/widgets/legal_text_screen.dart';
import 'legal_texts.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalTextScreen(
      appBarTitle: 'Términos y Condiciones',
      headerTitle: 'Acuerdo de Uso',
      headerSubtitle: 'Por favor lee atentamente las condiciones de servicio.',
      headerIcon: Icons.gavel_outlined,
      accentColorBuilder: (ctx) => ctx.colors.accent,
      legalText: LegalTexts.termsConditions,
    );
  }
}