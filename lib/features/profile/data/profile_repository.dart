import 'package:dio/dio.dart';
import '../../../core/models/user_profile.dart';
import 'profile_api_client.dart';

/// Repository for user profile operations
class ProfileRepository {
  final ProfileApiClient _apiClient;

  ProfileRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    ProfileApiClient? apiClient,
  }) : _apiClient = apiClient ?? ProfileApiClient(baseUrl: baseUrl);

  /// Get user profile by user ID
  Future<ProfileResult> getProfile(String userId, {required String accessToken}) async {
    try {
      final profile = await _apiClient.getUserProfile(userId, accessToken: accessToken);
      return ProfileResult.success(profile: profile);
    } on DioException catch (e) {
      return _handleDioException(e, 'Failed to fetch profile');
    } catch (e) {
      return ProfileResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Create user profile
  Future<ProfileResult> createProfile(UserProfile profile, {required String accessToken}) async {
    try {
      final createdProfile = await _apiClient.createUserProfile(profile, accessToken: accessToken);
      return ProfileResult.success(profile: createdProfile);
    } on DioException catch (e) {
      return _handleDioException(e, 'Failed to create profile');
    } catch (e) {
      return ProfileResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Update user profile
  Future<ProfileResult> updateProfile(UserProfile profile, {required String accessToken}) async {
    try {
      final updatedProfile = await _apiClient.updateUserProfile(
        profile.userId,
        profile,
        accessToken: accessToken,
      );
      return ProfileResult.success(profile: updatedProfile);
    } on DioException catch (e) {
      return _handleDioException(e, 'Failed to update profile');
    } catch (e) {
      return ProfileResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Upload profile picture
  Future<ProfilePictureResult> uploadProfilePicture(
    String userId,
    String filePath, {
    required String accessToken,
  }) async {
    try {
      final profilePicUrl = await _apiClient.uploadProfilePicture(
        userId,
        filePath,
        accessToken: accessToken,
      );
      return ProfilePictureResult.success(profilePicUrl: profilePicUrl);
    } on DioException catch (e) {
      return _handlePictureDioException(e, 'Failed to upload profile picture');
    } catch (e) {
      return ProfilePictureResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Handle Dio exceptions for profile operations
  ProfileResult _handleDioException(DioException e, String defaultMessage) {
    String errorMessage = defaultMessage;

    if (e.response?.statusCode == 400) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        errorMessage = responseData['message'];
      } else {
        errorMessage = 'Invalid profile data';
      }
    } else if (e.response?.statusCode == 404) {
      errorMessage = 'Profile not found';
    } else if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
      errorMessage = 'Authentication required';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      errorMessage = 'Connection timeout. Please try again.';
    } else if (e.type == DioExceptionType.connectionError) {
      errorMessage = 'Could not connect to server';
    }

    return ProfileResult.failure(message: errorMessage);
  }

  /// Handle Dio exceptions for picture upload
  ProfilePictureResult _handlePictureDioException(DioException e, String defaultMessage) {
    String errorMessage = defaultMessage;

    if (e.response?.statusCode == 400) {
      errorMessage = 'Invalid image file';
    } else if (e.response?.statusCode == 413) {
      errorMessage = 'Image file is too large';
    } else if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
      errorMessage = 'Authentication required';
    }

    return ProfilePictureResult.failure(message: errorMessage);
  }
}

/// Profile operation result wrapper
class ProfileResult {
  final bool success;
  final String message;
  final UserProfile? profile;

  const ProfileResult._({
    required this.success,
    required this.message,
    this.profile,
  });

  factory ProfileResult.success({
    required UserProfile profile,
    String message = 'Success',
  }) {
    return ProfileResult._(
      success: true,
      message: message,
      profile: profile,
    );
  }

  factory ProfileResult.failure({
    required String message,
  }) {
    return ProfileResult._(
      success: false,
      message: message,
    );
  }
}

/// Profile picture upload result wrapper
class ProfilePictureResult {
  final bool success;
  final String message;
  final String? profilePicUrl;

  const ProfilePictureResult._({
    required this.success,
    required this.message,
    this.profilePicUrl,
  });

  factory ProfilePictureResult.success({
    required String profilePicUrl,
    String message = 'Success',
  }) {
    return ProfilePictureResult._(
      success: true,
      message: message,
      profilePicUrl: profilePicUrl,
    );
  }

  factory ProfilePictureResult.failure({
    required String message,
  }) {
    return ProfilePictureResult._(
      success: false,
      message: message,
    );
  }
}
