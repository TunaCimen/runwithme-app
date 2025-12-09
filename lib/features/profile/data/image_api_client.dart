import 'dart:convert';
import 'package:dio/dio.dart';

/// API client for image upload endpoints
class ImageApiClient {
  final Dio _dio;
  final String _baseUrl;

  ImageApiClient({
    required String baseUrl,
    Dio? dio,
  })  : _baseUrl = baseUrl,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'Accept': 'application/json',
              },
            ));

  /// Set authorization token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Upload a profile picture
  /// POST /api/v1/images/profile-pictures
  /// Returns the filename of the uploaded image
  Future<String> uploadProfilePicture(String filePath) async {
    print('[ImageApiClient] uploadProfilePicture called: $filePath');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });

    final response = await _dio.post(
      '/api/v1/images/profile-pictures',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    print('[ImageApiClient] uploadProfilePicture response: ${response.statusCode}');
    print('[ImageApiClient] uploadProfilePicture data: ${response.data}');

    final data = _decodeResponse(response.data);

    // The API might return the filename in different ways
    // Try common field names
    final filename = data['filename'] ??
        data['fileName'] ??
        data['file_name'] ??
        data['url'] ??
        data['imageUrl'] ??
        data['image_url'] ??
        data['path'] ??
        data['profilePicUrl'] ??
        data['profile_pic_url'];

    if (filename == null) {
      print('[ImageApiClient] Response data keys: ${data.keys.toList()}');
      throw Exception('No filename returned from upload API. Response: $data');
    }

    print('[ImageApiClient] Uploaded filename: $filename');
    return filename.toString();
  }

  /// Get the full URL for a profile picture
  /// GET /api/v1/images/profile-pictures/{filename}
  String getProfilePictureUrl(String filename) {
    // If it's already a full URL, return as is
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }
    // Otherwise, construct the URL
    return '$_baseUrl/api/v1/images/profile-pictures/$filename';
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        return json.decode(data) as Map<String, dynamic>;
      } catch (e) {
        // If it's just a string filename, return it wrapped
        return {'filename': data};
      }
    }
    throw FormatException('Unexpected response format: $data');
  }
}
