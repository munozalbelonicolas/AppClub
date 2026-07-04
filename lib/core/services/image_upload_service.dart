import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
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

  /// Upload a product image and return its secure URL.
  static Future<String> uploadProductImage(File file, {String? productId}) async {
    return _uploadToCloudinary(file);
  }

  /// Upload a payment receipt image and return its secure URL.
  static Future<String> uploadReceipt(File file, String orderId) async {
    return _uploadToCloudinary(file);
  }

  /// Helper to post the image to Cloudinary API.
  static Future<String> _uploadToCloudinary(File file) async {
    try {
      final compressedFile = await _compressFile(file);
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', compressedFile.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonMap = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonMap['secure_url'] as String;
      } else {
        AppLogger.error('Cloudinary upload failed', error: jsonMap['error']['message'], tag: 'ImageUpload');
        throw Exception('Error subiendo imagen: ${jsonMap['error']['message']}');
      }
    } catch (e) {
      AppLogger.error('Exception uploading image', error: e, tag: 'ImageUpload');
      rethrow;
    }
  }

  static Future<File> _compressFile(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.absolute.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 800,
      minHeight: 800,
    );

    if (result != null) {
      return File(result.path);
    }
    return file;
  }
}
