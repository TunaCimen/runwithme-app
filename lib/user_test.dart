// Demo test for user registration/login
import 'user.dart';
import 'package:dio/dio.dart';
import 'dart:math';

Future<void> main() async {
  print('=== User API Test ===\n');

  // Create client
  final client = UserApiClient(baseUrl: 'http://35.158.35.102:8080');

  try {
    // Generate random user data
    final random = Random();
    final randomNum = random.nextInt(10000);
    final username = 'testuser$randomNum';
    final email = 'test$randomNum@example.com';
    final password = 'password123';

    print('Registering random user:');
    print('  Username: $username');
    print('  Email: $email');
    print('  Password: $password');
    print('');
    
    final response = await client.registerUser(
      username: username,
      email: email,
      password: password,
    );
    
    print('✓ Success!');
    print('Response from API:');
    print('  $response');
    
    if (response.user != null) {
      print('\nUser Details:');
      print('  User ID: ${response.user!.userId}');
      print('  Username: ${response.user!.userName}');
      print('  Email: ${response.user!.email}');
      print('  Token Type: ${response.user!.tokenType}');
      print('  Access Token: ${response.user!.accessToken.substring(0, 20)}...');
    }
    
  } on DioException catch (e) {
    print('\n✗ API Error:');
    print('  Type: ${e.type}');
    print('  Message: ${e.message}');
    
    if (e.response != null) {
      print('  Status code: ${e.response?.statusCode}');
      print('  Response data: ${e.response?.data}');
    } else {
      print('  No response received.');
    }
  } catch (e) {
    print('\n✗ Unexpected Error:');
    print('  $e');
  }
}
