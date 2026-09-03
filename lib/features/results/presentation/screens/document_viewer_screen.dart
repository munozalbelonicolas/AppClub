import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/image_upload_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_button.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String title;
  final String fileName;
  final String? fileUrl;
  final String? previewUrl;
  final String? format;
  final int pageCount;
  final String? publicId;
  final String? version;

  const DocumentViewerScreen({
    super.key,
    required this.title,
    required this.fileName,
    this.fileUrl,
    this.previewUrl,
    this.format,
    this.pageCount = 1,
    this.publicId,
    this.version,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  late int _totalPages;
  String? _resolvedPublicId;
  String? _resolvedVersion;
  late String _resolvedFormat;

  @override
  void initState() {
    super.initState();
    _totalPages = widget.pageCount > 0 ? widget.pageCount : 1;
    _pageController = PageController();

    _resolvedPublicId = widget.publicId;
    _resolvedVersion = widget.version;

    // Detect format from extension or parameter
    final ext = widget.fileName.split('.').last.toLowerCase();
    _resolvedFormat = (widget.format ?? ext).toLowerCase();

    // If publicId was not saved but fileUrl is Cloudinary, extract it
    if (_resolvedPublicId == null && widget.fileUrl != null) {
      final reg = RegExp(r'upload/(?:v(\d+)/)?([^/.]+)\.(pdf|jpg|jpeg|png|webp)', caseSensitive: false);
      final match = reg.firstMatch(widget.fileUrl!);
      if (match != null) {
        _resolvedVersion = match.group(1);
        _resolvedPublicId = match.group(2);
        if (match.group(3) != null) {
          _resolvedFormat = match.group(3)!.toLowerCase();
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isMockUrl => widget.fileUrl != null && widget.fileUrl!.contains('example.com');

  bool get _isPdf => _resolvedFormat == 'pdf';

  bool get _isImage => ['jpg', 'jpeg', 'png', 'webp'].contains(_resolvedFormat);

  Future<void> _openExternal() async {
    final url = widget.fileUrl;
    if (url == null || url.isEmpty) return;

    if (_isMockUrl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este informe contiene un enlace de prueba y no un archivo real.'),
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir archivo: $e')),
        );
      }
    }
  }

  Future<void> _shareFile() async {
    final url = widget.fileUrl;
    if (url == null || url.isEmpty || _isMockUrl) return;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Informe: ${widget.title}\n$url',
          subject: widget.fileName,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: context.typography.titleMedium),
            Text(
              widget.fileName,
              style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (!_isMockUrl && widget.fileUrl != null) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartir',
              onPressed: _shareFile,
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Abrir en navegador',
              onPressed: _openExternal,
            ),
          ],
        ],
      ),
      body: _buildBody(context),
      bottomNavigationBar: (_isPdf && _totalPages > 1 && !_isMockUrl)
          ? _buildBottomPageBar(context)
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isMockUrl) {
      return _buildMockWarning(context);
    }

    if (_isPdf) {
      return _buildPdfViewer(context);
    }

    if (_isImage && widget.fileUrl != null) {
      return _buildImageViewer(context, widget.fileUrl!);
    }

    // Generic document fallback (.doc, .docx, etc.)
    return _buildGenericDocViewer(context);
  }

  Widget _buildMockWarning(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 72, color: context.colors.warning),
            const SizedBox(height: 16),
            Text(
              'Archivo no disponible',
              style: context.typography.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Este informe ("${widget.title}") fue guardado previamente con un enlace de prueba simulado (example.com).\n\nPara poder visualizarlo correctamente, elimina este informe y vuelve a cargarlo con el archivo original.',
              style: context.typography.bodyMedium.copyWith(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            JNButton(
              label: 'Volver',
              icon: Icons.arrow_back,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewer(BuildContext context) {
    if (_resolvedPublicId == null && (widget.previewUrl == null || widget.previewUrl!.isEmpty)) {
      return _buildGenericDocViewer(context);
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _totalPages,
      onPageChanged: (page) {
        setState(() => _currentPage = page);
      },
      itemBuilder: (context, index) {
        final pageNum = index + 1;
        final pageUrl = _resolvedPublicId != null
            ? ImageUploadService.getPdfPageUrl(
                _resolvedPublicId!,
                pageNum,
                version: _resolvedVersion,
              )
            : widget.previewUrl!;

        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: pageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Cargando página $pageNum...',
                      style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              errorWidget: (context, url, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined, size: 48, color: context.colors.error),
                      const SizedBox(height: 12),
                      Text(
                        'No se pudo cargar la página $pageNum.',
                        style: context.typography.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Descargar archivo original'),
                        onPressed: _openExternal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageViewer(BuildContext context, String imageUrl) {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) => Center(
            child: Icon(Icons.broken_image_outlined, size: 64, color: context.colors.error),
          ),
        ),
      ),
    );
  }

  Widget _buildGenericDocViewer(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 72, color: context.colors.primary),
            const SizedBox(height: 16),
            Text(
              widget.fileName,
              style: context.typography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Este formato no admite previsualización en pantalla completa dentro de la app.',
              style: context.typography.bodyMedium.copyWith(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            JNButton(
              label: 'Descargar / Abrir documento',
              icon: Icons.download,
              onPressed: _openExternal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPageBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.colors.surface,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: _currentPage > 0
                  ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
            Text(
              'Página ${_currentPage + 1} de $_totalPages',
              style: context.typography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: _currentPage < _totalPages - 1
                  ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
