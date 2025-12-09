import 'package:dio/dio.dart';
import '../../../core/models/user_profile.dart';
import 'profile_api_client.dart';
import 'image_api_client.dart';

/// Repository for user profile operations
/// Uses singleton pattern to share cache across all pages
class ProfileRepository {
  // Singleton instance
  static ProfileRepository? _instance;

  /// Get the singleton instance
  static ProfileRepository get instance {
    _instance ??= ProfileRepository._internal();
    return _instance!;
  }

  final ProfileApiClient _apiClient;
  final ImageApiClient _imageApiClient;
  final String _baseUrl;

  // ==================== Cache ====================

  /// Cache for user profiles by userId
  final Map<String, UserProfile> _profileCache = {};

  /// Cache timestamps for expiry
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Cache duration (default 5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Private constructor for singleton
  ProfileRepository._internal({
    String baseUrl = 'http://35.158.35.102:8080',
    ProfileApiClient? apiClient,
    ImageApiClient? imageApiClient,
  })  : _baseUrl = baseUrl,
        _apiClient = apiClient ?? ProfileApiClient(baseUrl: baseUrl),
        _imageApiClient = imageApiClient ?? ImageApiClient(baseUrl: baseUrl);

  /// Factory constructor that returns singleton
  factory ProfileRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    ProfileApiClient? apiClient,
    ImageApiClient? imageApiClient,
  }) {
    _instance ??= ProfileRepository._internal(
      baseUrl: baseUrl,
      apiClient: apiClient,
      imageApiClient: imageApiClient,
    );
    return _instance!;
  }

  // ==================== Cache Management ====================

  /// Check if cache entry is still valid
  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  /// Update cache timestamp
  void _updateCacheTimestamp(String cacheKey) {
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  /// Clear all caches (for pull-to-refresh)
  void clearCache() {
    _profileCache.clear();
    _cacheTimestamps.clear();
    print('[ProfileRepository] Cache cleared');
  }

  /// Get cached profile without API call (returns null if not cached)
  UserProfile? getCachedProfile(String userId) => _profileCache[userId];

  // ==================== Profile Operations ====================

  /// Get user profile by user ID
  /// Set [forceRefresh] to true to bypass cache (e.g., on pull-to-refresh)
  Future<ProfileResult> getProfile(String userId, {
    required String accessToken,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'profile_$userId';

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      final cachedProfile = _profileCache[userId];
      if (cachedProfile != null) {
        print('[ProfileRepository] Returning cached profile for $userId');
        return ProfileResult.success(profile: cachedProfile);
      }
    }

    try {
      final profile = await _apiClient.getUserProfile(userId, accessToken: accessToken);

      // Cache the result
      _profileCache[userId] = profile;
      _updateCacheTimestamp(cacheKey);

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

      // Update cache with new profile data
      _profileCache[profile.userId] = updatedProfile;
      _updateCacheTimestamp('profile_${profile.userId}');

      return ProfileResult.success(profile: updatedProfile);
    } on DioException catch (e) {
      return _handleDioException(e, 'Failed to update profile');
    } catch (e) {
      return ProfileResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Upload profile picture using the new images API
  /// 1. Upload image to POST /api/v1/images/profile-pictures
  /// 2. Update user profile with the returned filename
  Future<ProfilePictureResult> uploadProfilePicture(
    String userId,
    String filePath, {
    required String accessToken,
  }) async {
    try {
      // Set auth token for image API
      _imageApiClient.setAuthToken(accessToken);

      // Step 1: Upload the image
      print('[ProfileRepository] Uploading profile picture...');
      final filename = await _imageApiClient.uploadProfilePicture(filePath);
      print('[ProfileRepository] Upload successful, filename: $filename');

      // Step 2: Get the full URL for display
      final profilePicUrl = _imageApiClient.getProfilePictureUrl(filename);
      print('[ProfileRepository] Profile picture URL: $profilePicUrl');

      return ProfilePictureResult.success(profilePicUrl: filename);
    } on DioException catch (e) {
      print('[ProfileRepository] Upload failed: ${e.message}');
      print('[ProfileRepository] Response: ${e.response?.data}');
      return _handlePictureDioException(e, 'Failed to upload profile picture');
    } catch (e) {
      print('[ProfileRepository] Upload error: $e');
      return ProfilePictureResult.failure(message: 'An unexpected error occurred: $e');
    }
  }

  /// Get the full URL for a profile picture filename
  String getProfilePictureUrl(String filename) {
    return _imageApiClient.getProfilePictureUrl(filename);
  }

  /// Get the base URL
  String get baseUrl => _baseUrl;

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
