import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';

class ExportPostDialog extends StatefulWidget {
  final String postId;

  const ExportPostDialog({super.key, required this.postId});

  @override
  State<ExportPostDialog> createState() => _ExportPostDialogState();
}

class _ExportPostDialogState extends State<ExportPostDialog> {
  String _selectedFormat = 'instagram_feed';
  bool _isGenerating = false;

  final Map<String, Map<String, dynamic>> _formats = {
    'instagram_feed': {
      'label': 'Instagram Feed (1:1)',
      'icon': Icons.grid_on,
      'width': 1080,
      'height': 1080,
    },
    'instagram_story': {
      'label': 'Instagram Story (9:16)',
      'icon': Icons.portrait,
      'width': 1080,
      'height': 1920,
    },
    'facebook': {
      'label': 'Facebook Post',
      'icon': Icons.facebook,
      'width': 1200,
      'height': 630,
    },
    'twitter': {
      'label': 'X (Twitter)',
      'icon': Icons.chat_bubble_outline,
      'width': 1600,
      'height': 900,
    },
    'whatsapp': {
      'label': 'WhatsApp',
      'icon': Icons.wechat,
      'width': 1080,
      'height': 1350,
    },
    'high_res': {
      'label': 'Alta Resolución',
      'icon': Icons.high_quality,
      'width': 2160,
      'height': 2160,
    },
  };

  Future<void> _generateAndShare() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'exportPostImage',
      );
      final results = await callable.call(<String, dynamic>{
        'postId': widget.postId,
        'format': _selectedFormat,
      });

      final String base64Image = results.data['base64Image'];
      final imageBytes = base64Decode(base64Image);

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/export_${widget.postId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(imagePath);
      await file.writeAsBytes(imageBytes);

      if (mounted) {
        Navigator.pop(context); // Close dialog
      }

      // Share
      final xFile = XFile(imagePath);
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        xFile,
      ], text: 'Mira nuestra última novedad en AppClub');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar imagen: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(color: context.colors.border, width: 0.5),
      ),
      title: Text('Exportar para Redes', style: context.typography.titleLarge),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona el formato de exportación:',
              style: context.typography.bodyMedium,
            ),
            const SizedBox(height: 16),
            ..._formats.entries.map((entry) {
              final isSelected = _selectedFormat == entry.key;
              final data = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedFormat = entry.key;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.colors.primary.withValues(alpha: 0.1)
                          : context.colors.surfaceLight,
                      border: Border.all(
                        color: isSelected
                            ? context.colors.primary
                            : context.colors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          data['icon'],
                          color: isSelected
                              ? context.colors.primary
                              : context.colors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['label'],
                                style: context.typography.titleSmall.copyWith(
                                  color: isSelected
                                      ? context.colors.primary
                                      : context.colors.textPrimary,
                                ),
                              ),
                              Text(
                                '${data['width']} x ${data['height']} px',
                                style: context.typography.labelSmall.copyWith(
                                  color: context.colors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: context.colors.primary),
                      ],
                    ),
                  ),
                ),
              );
            // ignore: unnecessary_to_list_in_spreads
            }).toList(),
            if (_isGenerating)
              const Padding(
                padding: EdgeInsets.only(top: 24.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        JNButton(
          label: 'Generar y Compartir',
          onPressed: _isGenerating ? () {} : _generateAndShare,
          icon: Icons.share,
        ),
      ],
    );
  }
}
