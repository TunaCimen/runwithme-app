// lib/api/student_api_client.dart
// Requires: dio ^5.7.0 in pubspec.yaml

import 'dart:convert';
import 'package:dio/dio.dart';

class StudentApiClient {
  final Dio _dio;

  StudentApiClient({
    required baseUrl,
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
  final int studentId;
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String email;

  StudentDto({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.email,
  });

  factory StudentDto.fromJson(Map<String, dynamic> json) => StudentDto(
        studentId: (json['studentId'] as num?)?.toInt() ?? 0,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        dateOfBirth: json['dateOfBirth'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'firstName': firstName,
        'lastName' : lastName,
        'dateOfBirth': dateOfBirth,
        'email': email,
      };

   String getFullName(){
      return "$firstName $lastName";
   }
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
      page: (json['pageNumber'] as num?)?.toInt() ?? 0,
      size: (json['pageSize'] as num?)?.toInt() ?? items.length,
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
