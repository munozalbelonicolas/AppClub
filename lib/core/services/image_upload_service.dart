import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.absolute.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 80,
        minWidth: 1080,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        if (await compressedFile.exists() && await compressedFile.length() > 0) {
          return compressedFile;
        }
      }
    } catch (e) {
      AppLogger.error('Image compression failed, proceeding with original file', error: e, tag: 'ImageUpload');
    }
    return file;
  }
}
