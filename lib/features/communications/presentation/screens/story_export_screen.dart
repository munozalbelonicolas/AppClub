import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';

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
  ImageProvider? _imageProvider;
  bool _imageLoaded = false;

  String? _resolveImageUrl() {
    final raw = widget.announcement['imageUrl'] ??
        widget.announcement['image'] ??
        widget.announcement['attachmentUrl'] ??
        widget.announcement['mediaUrl'] ??
        widget.announcement['photoUrl'];
    if (raw != null && raw.toString().trim().isNotEmpty) {
      return raw.toString().trim();
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final url = _resolveImageUrl();
    if (url != null && !_imageLoaded) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        _imageProvider = NetworkImage(url);
      } else {
        _imageProvider = FileImage(File(url));
      }
      precacheImage(_imageProvider!, context).then((_) {
        if (mounted) {
          setState(() => _imageLoaded = true);
        }
      }).catchError((_) {});
    }
  }

  Widget _buildStoryImage(String url, {BoxFit fit = BoxFit.contain}) {
    final clean = url.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
        ),
      );
    } else {
      return Image.file(
        File(clean),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
        ),
      );
    }
  }

  Future<void> _captureAndShare() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      // Ensure image is loaded before capturing
      final url = _resolveImageUrl();
      if (url != null && !_imageLoaded) {
        int waits = 0;
        while (!_imageLoaded && waits < 15) {
          await Future.delayed(const Duration(milliseconds: 100));
          waits++;
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 150));
      }

      final boundary = _globalKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('No se pudo encontrar el lienzo para capturar.');
      }

      // Wait if the frame still needs paint (only in debug mode, debugNeedsPaint throws LateInitializationError in release)
      if (kDebugMode) {
        int retries = 0;
        while (boundary.debugNeedsPaint && retries < 10) {
          await Future.delayed(const Duration(milliseconds: 50));
          retries++;
        }
      }

      // The Container is already 1080x1920, pixelRatio 1.0 yields full HD 1080x1920 image
      final image = await boundary
          .toImage()
          .timeout(const Duration(seconds: 4), onTimeout: () {
        throw Exception('Tiempo de espera agotado al renderizar imagen.');
      });

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Error al convertir imagen a PNG.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/historia_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      // Stop loading state before opening native share sheet
      if (mounted) {
        setState(() => _isExporting = false);
      }

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      final title = widget.announcement['title']?.toString() ?? 'Novedad Club';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: title,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
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

  String _resolveDate() {
    final rawDate = widget.announcement['date']?.toString();
    if (rawDate != null && rawDate.trim().isNotEmpty) {
      return rawDate;
    }
    final createdAt = widget.announcement['createdAt'];
    if (createdAt != null) {
      try {
        if (createdAt is DateTime) {
          return DateFormat('dd/MM/yyyy').format(createdAt);
        }
        final dt = (createdAt as dynamic).toDate();
        return DateFormat('dd/MM/yyyy').format(dt as DateTime);
      } catch (_) {}
    }
    return DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final isBirthday = widget.announcement['type'] == 'birthday' ||
        (widget.announcement['title'] ?? '')
            .toString()
            .toLowerCase()
            .contains('cumpleaños');

    final dateStr = _resolveDate();
    final authorStr =
        widget.announcement['authorName']?.toString() ?? 'Club Jorge Newbery';
    final categoryStr = widget.announcement['category']?.toString();
    final imageUrl = _resolveImageUrl();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final bodyText = (widget.announcement['body'] ?? '').toString().trim();

    String badgeText;
    if (isBirthday) {
      badgeText = '¡CUMPLEAÑOS!';
    } else {
      final rawEvent = widget.announcement['eventType']?.toString() ??
          widget.announcement['type']?.toString();
      if (rawEvent != null &&
          rawEvent.trim().isNotEmpty &&
          rawEvent.toLowerCase() != 'ninguno') {
        final ev = rawEvent.toLowerCase().trim();
        if (ev == 'torneo') {
          badgeText = 'TORNEO 🏆';
        } else if (ev == 'comunicado') {
          badgeText = 'COMUNICADO OFICIAL 📢';
        } else if (ev == 'partido') {
          badgeText = 'PRÓXIMO PARTIDO ⚽';
        } else {
          badgeText = rawEvent.toUpperCase();
        }
      } else {
        badgeText = 'COMUNICADO OFICIAL';
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          isBirthday ? 'Exportar Saludo de Cumpleaños' : 'Exportar para Historia',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
                  child: RepaintBoundary(
                    key: _globalKey,
                    child: Container(
                      width: 1080,
                      height: 1920, // 9:16 Story format
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isBirthday
                              ? [
                                  const Color(0xFF1E293B), // Slate dark
                                  const Color(0xFF0F172A),
                                  const Color(0xFF090D16),
                                ]
                              : [
                                  context.colors.primary,
                                  const Color(0xFF6B1A1A), // Deep red
                                ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Background App Logo Watermark (using app_logo.jpg)
                          Positioned.fill(
                            child: Center(
                              child: Opacity(
                                opacity: 0.06,
                                child: Image.asset(
                                  'assets/images/app_logo.jpg',
                                  width: 800,
                                  height: 800,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(),
                                ),
                              ),
                            ),
                          ),

                          // Birthday decorative top badge glow
                          if (isBirthday)
                            Positioned(
                              top: -100,
                              right: -100,
                              child: Container(
                                width: 400,
                                height: 400,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                            ),

                          // Story Card Content
                          Padding(
                            padding: const EdgeInsets.all(80.0),
                            child: hasImage
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),

                                      // ─── Header: Badge + Category ───
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 28,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isBirthday
                                                  ? const Color(0xFFD4AF37)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isBirthday)
                                                  const Text(
                                                    '🎂 ',
                                                    style: TextStyle(fontSize: 28),
                                                  ),
                                                Text(
                                                  badgeText,
                                                  style: TextStyle(
                                                    color: isBirthday
                                                        ? Colors.black
                                                        : context.colors.primary,
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          if (categoryStr != null &&
                                              categoryStr.isNotEmpty &&
                                              categoryStr.toLowerCase() != 'all')
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                  BorderRadius.circular(100),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                'CAT. ${categoryStr.toUpperCase()}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      const SizedBox(height: 28),

                                      // ─── Title ───
                                      Text(
                                        widget.announcement['title'] ?? '',
                                        style: TextStyle(
                                          color: isBirthday
                                              ? const Color(0xFFFBBF24)
                                              : Colors.white,
                                          fontSize: 60,
                                          fontWeight: FontWeight.w900,
                                          height: 1.15,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      if (bodyText.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        // ─── Body Text (compact card) ───
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 28,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: isBirthday ? 0.3 : 0.2,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            bodyText,
                                            style: const TextStyle(
                                              color: Color(0xFFF1F5F9),
                                              fontSize: 34,
                                              fontWeight: FontWeight.w400,
                                              height: 1.35,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 24),

                                      // ─── HERO IMAGE CONTAINER ───
                                      Expanded(
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.4),
                                            borderRadius:
                                                BorderRadius.circular(28),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.25),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.45),
                                                blurRadius: 24,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(26),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                // Ambient blurred background to fill the frame
                                                ImageFiltered(
                                                  imageFilter:
                                                      ui.ImageFilter.blur(
                                                    sigmaX: 30,
                                                    sigmaY: 30,
                                                  ),
                                                  child: Opacity(
                                                    opacity: 0.45,
                                                    child: _buildStoryImage(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                                // Sharp full-detail foreground image
                                                Center(
                                                  child: _buildStoryImage(
                                                    imageUrl,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 28),

                                      // ─── Footer: Date & Signature ───
                                      const Divider(
                                        color: Colors.white30,
                                        thickness: 2,
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'FECHA',
                                                style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                dateStr,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const Text(
                                                'PUBLICADO POR',
                                                style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                authorStr,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 80),

                                      // ─── Header: Badge + Category ───
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 28,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isBirthday
                                                  ? const Color(0xFFD4AF37)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isBirthday) ...[
                                                  const Text(
                                                    '🎂 ',
                                                    style: TextStyle(fontSize: 28),
                                                  ),
                                                ],
                                                Text(
                                                  badgeText,
                                                  style: TextStyle(
                                                    color: isBirthday
                                                        ? Colors.black
                                                        : context.colors.primary,
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          if (categoryStr != null &&
                                              categoryStr.isNotEmpty &&
                                              categoryStr.toLowerCase() != 'all')
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(100),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                'CAT. ${categoryStr.toUpperCase()}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      const SizedBox(height: 100),

                                      // ─── Title ───
                                      Text(
                                        widget.announcement['title'] ?? '',
                                        style: TextStyle(
                                          color: isBirthday
                                              ? const Color(0xFFFBBF24) // Gold
                                              : Colors.white,
                                          fontSize: 84,
                                          fontWeight: FontWeight.w900,
                                          height: 1.1,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 50),

                                      // ─── Body Text ───
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(40),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: isBirthday ? 0.3 : 0.15,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(32),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            bodyText,
                                            style: const TextStyle(
                                              color: Color(0xFFF1F5F9),
                                              fontSize: 44,
                                              fontWeight: FontWeight.w400,
                                              height: 1.45,
                                            ),
                                            maxLines: 12,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 40),

                                      // ─── Footer: Date & Signature ───
                                      const Divider(
                                        color: Colors.white30,
                                        thickness: 2,
                                      ),
                                      const SizedBox(height: 30),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'FECHA',
                                                style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                dateStr,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 36,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const Text(
                                                'PUBLICADO POR',
                                                style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                authorStr,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 36,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 40),
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

            // ─── Bottom Action Button ───
            Container(
              padding: const EdgeInsets.all(24.0),
              color: Colors.black,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBirthday
                        ? const Color(0xFFD4AF37)
                        : context.colors.primary,
                    foregroundColor: isBirthday ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _isExporting ? null : _captureAndShare,
                  icon: _isExporting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: isBirthday ? Colors.black : Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.share, size: 22),
                  label: Text(
                    _isExporting ? 'Generando Imagen...' : 'Compartir en Redes',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
