// Test script for StudentApiClient
import 'client.dart';
import 'package:dio/dio.dart';

Future<void> main() async {
  print('=== Student API Client Test ===\n');

  // Create client instance
  final client = StudentApiClient(
    baseUrl: 'http://3.68.166.176:8080',
  );

  try {
    // Test 1: Get paginated students
    print('Test 1: Fetching students (page 0, size 5)...');
    final studentsPage = await client.getStudents(page: 0, size: 5);
    print('✓ Success!');
    print('  Total elements: ${studentsPage.totalElements}');
    print('  Total pages: ${studentsPage.totalPages}');
    print('  Current page: ${studentsPage.page}');
    print('  Students in this page: ${studentsPage.content.length}');
   
    print('\n✓ All tests passed!');
    
  } on DioException catch (e) {
    print('\n✗ API Error:');
    print('  Type: ${e.type}');
    print('  Message: ${e.message}');
    
    if (e.response != null) {
      print('  Status code: ${e.response?.statusCode}');
      print('  Response data: ${e.response?.data}');
    } else {
      print('  No response received.');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
  
      } else if (e.type == DioExceptionType.connectionError) {
        print('  → Make sure your backend server is running');
      }
    }
  } on FormatException catch (e) {
    print('\n✗ Format Error:');
    print('  ${e.message}');
    print('  → Check if the API response matches the expected JSON structure');
  } catch (e) {
    print('\n✗ Unexpected Error:');
    print('  $e');
  }
}
