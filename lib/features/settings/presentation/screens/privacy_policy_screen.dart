import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import 'legal_texts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Política de Privacidad'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              JNCard(
                padding: const EdgeInsets.all(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surfaceLight, AppColors.primary.withValues(alpha: 0.05)],
                ),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seguridad y Confianza',
                            style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tu privacidad es nuestra prioridad en AppClub.',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Parsed Legal Text
              ..._parseLegalText(LegalTexts.privacyPolicy),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _parseLegalText(String rawText) {
    final List<Widget> widgets = [];
    final lines = rawText.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (trimmed.startsWith('# ')) {
        final title = trimmed.substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Text(
              title,
              style: AppTypography.headlineLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        final title = trimmed.substring(3);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('* ')) {
        final itemText = trimmed.substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    itemText,
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (trimmed == '---') {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.divider, height: 1),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              trimmed,
              style: AppTypography.bodyMedium,
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
