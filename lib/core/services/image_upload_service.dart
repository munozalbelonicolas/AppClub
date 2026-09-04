import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import 'app_logger.dart';

/// Centralized service for uploading images to Cloudinary.
///
/// Handles product images and payment receipts using a free
/// Cloudinary account without requiring Firebase Storage billing.
class ImageUploadService {
  static const String _cloudName = 'dp54uogda';
  static const String _uploadPreset = 'AppClub';
  static const String _apiUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
  static const String _rawApiUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/raw/upload';

  /// Upload a document (PDF, Office document, or image) to Cloudinary.
  /// Returns a map with metadata for in-app viewing and downloading:
  /// - `fileUrl`: secure download/resource URL
  /// - `publicId`: Cloudinary public ID
  /// - `version`: Cloudinary asset version
  /// - `format`: 'pdf', 'png', 'jpg', 'docx', etc.
  /// - `pageCount`: number of pages (for PDF)
  /// - `previewUrl`: high-res image URL of the first page
  static Future<Map<String, dynamic>> uploadDocument(File file, {String? originalFileName}) async {
    final fileName = originalFileName ?? file.path.split(Platform.pathSeparator).last;
    final extension = fileName.split('.').last.toLowerCase();
    final isPdfOrImage = ['pdf', 'jpg', 'jpeg', 'png', 'webp'].contains(extension);
    final endpoint = isPdfOrImage ? _apiUrl : _rawApiUrl;

    try {
      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest('POST', Uri.parse(endpoint));
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonMap = json.decode(responseData);

      if (response.statusCode == 200) {
        final secureUrl = jsonMap['secure_url'] as String;
        final publicId = jsonMap['public_id'] as String;
        final version = jsonMap['version']?.toString();
        final format = (jsonMap['format'] ?? extension).toString().toLowerCase();
        final pageCount = jsonMap['pages'] is int ? jsonMap['pages'] as int : 1;

        String previewUrl;
        if (format == 'pdf') {
          previewUrl = getPdfPageUrl(publicId, 1, version: version);
        } else if (isPdfOrImage) {
          previewUrl = secureUrl;
        } else {
          previewUrl = '';
        }

        return {
          'fileUrl': secureUrl,
          'publicId': publicId,
          'version': version,
          'format': format,
          'pageCount': pageCount,
          'previewUrl': previewUrl,
        };
      } else {
        AppLogger.error('Cloudinary upload failed', error: jsonMap['error']?['message'], tag: 'ImageUpload');
        throw Exception('Error subiendo archivo: ${jsonMap['error']?['message'] ?? 'Error desconocido'}');
      }
    } catch (e) {
      AppLogger.error('Exception uploading document', error: e, tag: 'ImageUpload');
      rethrow;
    }
  }

  /// Generate a high-resolution PNG image URL for a specific page of a PDF.
  static String getPdfPageUrl(String publicId, int page, {String? version}) {
    final versionPath = version != null ? 'v$version/' : '';
    return 'https://res.cloudinary.com/$_cloudName/image/upload/pg_$page/$versionPath$publicId.png';
  }

  /// Upload a product image and return its secure URL.
  static Future<String> uploadProductImage(File file, {String? productId}) async {
    return _uploadToCloudinary(file);
  }

  /// Upload a novelty / post image and return its secure URL.
  static Future<String> uploadPostImage(File file) async {
    return _uploadToCloudinary(file);
  }

  /// Upload a sponsor image and return its secure URL.
  static Future<String> uploadSponsorImage(File file) async {
    return _uploadToCloudinary(file);
  }

  /// Upload a payment receipt image and return its secure URL.
  static Future<String> uploadReceipt(File file, String orderId) async {
    return _uploadToCloudinary(file);
  }

  /// Helper to post the image to Cloudinary API.
  static Future<String> _uploadToCloudinary(File file) async {
    try {
      Uint8List bytes;
      if (await file.exists()) {
        bytes = await file.readAsBytes();
      } else {
        throw Exception('El archivo de imagen no existe o no se pudo acceder.');
      }

      // Try compressing bytes safely
      Uint8List uploadBytes = bytes;
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 80,
          minWidth: 1080,
        );
        if (compressed.isNotEmpty) {
          uploadBytes = compressed;
        }
      } catch (e) {
        AppLogger.error('Image compression failed, proceeding with original bytes', error: e, tag: 'ImageUpload');
      }

      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          uploadBytes,
          filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonMap = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonMap['secure_url'] as String;
      } else {
        AppLogger.error('Cloudinary upload failed', error: jsonMap['error']?['message'], tag: 'ImageUpload');
        throw Exception('Error subiendo imagen: ${jsonMap['error']?['message'] ?? 'Error desconocido'}');
      }
    } catch (e) {
      AppLogger.error('Exception uploading image', error: e, tag: 'ImageUpload');
      rethrow;
    }
  }
}
