// lib/api/student_api_client.dart
// Requires: dio ^5.7.0 in pubspec.yaml

import 'dart:convert';
import 'package:dio/dio.dart';

class StudentApiClient {
  final Dio _dio;

  StudentApiClient({
    String baseUrl = 'http://localhost:8080',
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ));

  Future<PageResponseStudent> getStudents({int page = 0, int size = 5}) async {
    final res = await _dio.get(
      '/api/v1/students',
      queryParameters: {'page': page, 'size': size},
    );
    return PageResponseStudent.fromJson(_decodeResponse(res.data));
  }

  Future<StudentDto> getStudentById(int id) async {
    final res = await _dio.get('/api/v1/students/$id');
    return StudentDto.fromJson(_decodeResponse(res.data));
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return json.decode(data) as Map<String, dynamic>;
    throw FormatException('Unexpected response type: ${data.runtimeType}');
  }
}

class StudentDto {
  final int id;
  final String name;
  final int age;
  final String email;

  StudentDto({
    required this.id,
    required this.name,
    required this.age,
    required this.email,
  });

  factory StudentDto.fromJson(Map<String, dynamic> json) => StudentDto(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        age: (json['age'] as num).toInt(),
        email: json['email'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'email': email,
      };
}

class PageResponseStudent {
  final List<StudentDto> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;
  final bool first;

  PageResponseStudent({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
    required this.first,
  });

  factory PageResponseStudent.fromJson(Map<String, dynamic> json) {
    final items = (json['content'] as List<dynamic>? ?? [])
        .map((e) => StudentDto.fromJson(e as Map<String, dynamic>))
        .toList();

    return PageResponseStudent(
      content: items,
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? items.length,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? items.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      last: json['last'] as bool? ?? true,
      first: json['first'] as bool? ?? (json['page'] == 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content.map((e) => e.toJson()).toList(),
        'page': page,
        'size': size,
        'totalElements': totalElements,
        'totalPages': totalPages,
        'last': last,
        'first': first,
      };
}
