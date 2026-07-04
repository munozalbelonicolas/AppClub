import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';

/// Reusable screen for rendering legal text documents (terms, privacy, etc.)
/// Eliminates duplication between TermsConditionsScreen and PrivacyPolicyScreen.
class LegalTextScreen extends StatelessWidget {
  final String appBarTitle;
  final String headerTitle;
  final String headerSubtitle;
  final IconData headerIcon;
  final Color Function(BuildContext) accentColorBuilder;
  final String legalText;

  const LegalTextScreen({
    super.key,
    required this.appBarTitle,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.headerIcon,
    required this.accentColorBuilder,
    required this.legalText,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = accentColorBuilder(context);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(appBarTitle), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JNCard(
                padding: const EdgeInsets.all(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colors.surfaceLight,
                    accentColor.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.15),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(headerIcon, color: accentColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerTitle,
                            style: context.typography.titleLarge.copyWith(
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(headerSubtitle, style: context.typography.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ..._parseLegalText(context, accentColor),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _parseLegalText(BuildContext context, Color accentColor) {
    final List<Widget> widgets = [];
    final lines = legalText.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (trimmed.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Text(
              trimmed.substring(2),
              style: context.typography.headlineLarge.copyWith(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              trimmed.substring(3),
              style: context.typography.headlineSmall.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('* ')) {
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
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(trimmed.substring(2), style: context.typography.bodyMedium),
                ),
              ],
            ),
          ),
        );
      } else if (trimmed == '---') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: context.colors.divider, height: 1),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(trimmed, style: context.typography.bodyMedium),
          ),
        );
      }
    }

    return widgets;
  }
}
