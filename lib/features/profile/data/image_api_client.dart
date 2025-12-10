import 'dart:convert';
import 'package:dio/dio.dart';

/// API client for image upload endpoints
class ImageApiClient {
  final Dio _dio;
  final String _baseUrl;

  ImageApiClient({
    String baseUrl = 'http://35.158.35.102:8080',
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

  /// Upload an image to a specific folder
  /// POST /api/v1/images/upload?folder={folder}
  /// Returns the URL or filename of the uploaded image
  Future<String> uploadImage(String filePath, {String folder = 'posts'}) async {
    print('[ImageApiClient] uploadImage called: $filePath to folder: $folder');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });

    final response = await _dio.post(
      '/api/v1/images/upload',
      queryParameters: {'folder': folder},
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    print('[ImageApiClient] uploadImage response: ${response.statusCode}');
    print('[ImageApiClient] uploadImage data: ${response.data}');

    final data = _decodeResponse(response.data);

    // The API might return the URL in different ways
    final url = data['url'] ??
        data['imageUrl'] ??
        data['image_url'] ??
        data['filename'] ??
        data['fileName'] ??
        data['file_name'] ??
        data['path'];

    if (url == null) {
      print('[ImageApiClient] Response data keys: ${data.keys.toList()}');
      throw Exception('No URL returned from upload API. Response: $data');
    }

    // If the returned value is just a filename, construct the full URL
    var resultUrl = url.toString();
    if (!resultUrl.startsWith('http://') && !resultUrl.startsWith('https://')) {
      resultUrl = '$_baseUrl/api/v1/images/$folder/$resultUrl';
    }

    print('[ImageApiClient] Uploaded URL: $resultUrl');
    return resultUrl;
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

  /// Get the full URL for an image in a folder
  String getImageUrl(String filename, {String folder = 'posts'}) {
    // If it's already a full URL, return as is
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }
    // Otherwise, construct the URL
    return '$_baseUrl/api/v1/images/$folder/$filename';
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
