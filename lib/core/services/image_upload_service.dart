import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonMap = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonMap['secure_url'] as String;
      } else {
        debugPrint('Cloudinary Error: ${jsonMap['error']['message']}');
        throw Exception('Error subiendo imagen: ${jsonMap['error']['message']}');
      }
    } catch (e) {
      debugPrint('Exception uploading image: $e');
      rethrow;
    }
  }
}
