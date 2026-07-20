import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';

class StoryExportScreen extends StatefulWidget {
  final Map<String, dynamic> announcement;

  const StoryExportScreen({
    super.key,
    required this.announcement,
  });

  @override
  State<StoryExportScreen> createState() => _StoryExportScreenState();
}

class _StoryExportScreenState extends State<StoryExportScreen> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isExporting = false;

  Future<void> _captureAndShare() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      // Small delay to ensure render is complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("No se pudo capturar la vista");

      // We use a high pixel ratio for a crisp image
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/comunicado_story_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Novedad Oficial',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Previsualizar Historia', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _globalKey,
                    child: Container(
                      width: 1080,
                      height: 1920, // 9:16 aspect ratio
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.primary,
                            const Color(0xFF6B1A1A), // Darker red
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Background pattern or logo watermark
                          Positioned.fill(
                            child: Center(
                              child: Opacity(
                                opacity: 0.05,
                                child: Image.asset(
                                  'assets/images/logo.png', // Ensure this exists, otherwise it's just blank
                                  width: 800,
                                  height: 800,
                                  errorBuilder: (_, __, ___) => const SizedBox(),
                                ),
                              ),
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(80.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 100),
                                // Header: Club + Categoría
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        'COMUNICADO OFICIAL',
                                        style: TextStyle(
                                          color: context.colors.primary,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (widget.announcement['category'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                        child: Text(
                                          widget.announcement['category'].toString().toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 120),
                                // Title
                                Text(
                                  widget.announcement['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 90,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 60),
                                // Body
                                Expanded(
                                  child: Text(
                                    widget.announcement['body'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.w400,
                                      height: 1.4,
                                    ),
                                    maxLines: 15,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Footer: Date and Author
                                const Divider(color: Colors.white54, thickness: 2),
                                const SizedBox(height: 40),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'FECHA',
                                          style: TextStyle(color: Colors.white54, fontSize: 32, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          widget.announcement['date'] ?? '',
                                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'PUBLICADO POR',
                                          style: TextStyle(color: Colors.white54, fontSize: 32, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          widget.announcement['authorName'] ?? 'Club',
                                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              color: Colors.black,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                  onPressed: _isExporting ? null : _captureAndShare,
                  icon: _isExporting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.share),
                  label: Text(
                    _isExporting ? 'Procesando...' : 'Compartir en Redes',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
