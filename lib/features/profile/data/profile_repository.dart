import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/user_statistics.dart';
import '../../../core/models/run_session.dart';
import '../../map/data/models/route_dto.dart';
import '../../feed/data/models/feed_post_dto.dart';
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
  }) : _baseUrl = baseUrl,
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
  }

  /// Get cached profile without API call (returns null if not cached)
  UserProfile? getCachedProfile(String userId) => _profileCache[userId];

  // ==================== Profile Operations ====================

  /// Get user profile by user ID
  /// Set [forceRefresh] to true to bypass cache (e.g., on pull-to-refresh)
  Future<ProfileResult> getProfile(
    String userId, {
    required String accessToken,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'profile_$userId';

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      final cachedProfile = _profileCache[userId];
      if (cachedProfile != null) {
        return ProfileResult.success(profile: cachedProfile);
      }
    }

    try {
      final profile = await _apiClient.getUserProfile(
        userId,
        accessToken: accessToken,
      );

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

  /// Get all user profiles (paginated)
  /// Returns a list of all users for matching purposes
  Future<AllProfilesResult> getAllProfiles({
    required String accessToken,
    int page = 0,
    int size = 20,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _apiClient.getAllProfiles(
        page: page,
        size: size,
        accessToken: accessToken,
      );

      // Cache each profile
      for (final profile in response.content) {
        _profileCache[profile.userId] = profile;
        _updateCacheTimestamp('profile_${profile.userId}');
      }

      return AllProfilesResult.success(
        profiles: response.content,
        totalElements: response.totalElements,
        totalPages: response.totalPages,
        hasMore: !response.last,
      );
    } on DioException catch (e) {
      final result = _handleDioException(e, 'Failed to fetch profiles');
      return AllProfilesResult.failure(message: result.message);
    } catch (e) {
      return AllProfilesResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Create user profile
  Future<ProfileResult> createProfile(
    UserProfile profile, {
    required String accessToken,
  }) async {
    try {
      final createdProfile = await _apiClient.createUserProfile(
        profile,
        accessToken: accessToken,
      );
      return ProfileResult.success(profile: createdProfile);
    } on DioException catch (e) {
      return _handleDioException(e, 'Failed to create profile');
    } catch (e) {
      return ProfileResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Update user profile
  Future<ProfileResult> updateProfile(
    UserProfile profile, {
    required String accessToken,
  }) async {
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
      _imageApiClient.setAuthToken(accessToken);
      final filename = await _imageApiClient.uploadProfilePicture(filePath);
      return ProfilePictureResult.success(profilePicUrl: filename);
    } on DioException catch (e) {
      return _handlePictureDioException(e, 'Failed to upload profile picture');
    } catch (e) {
      return ProfilePictureResult.failure(
        message: 'An unexpected error occurred',
      );
    }
  }

  /// Get the full URL for a profile picture filename
  String getProfilePictureUrl(String filename) {
    return _imageApiClient.getProfilePictureUrl(filename);
  }

  /// Get the base URL
  String get baseUrl => _baseUrl;

  /// Get user statistics
  Future<UserStatisticsResult> getUserStatistics(
    String userId, {
    required String accessToken,
    int? days,
  }) async {
    try {
      final statistics = await _apiClient.getUserStatistics(
        userId,
        accessToken: accessToken,
        days: days,
      );
      return UserStatisticsResult.success(statistics: statistics);
    } on DioException catch (e) {
      final result = _handleDioException(e, 'Failed to fetch statistics');
      return UserStatisticsResult.failure(message: result.message);
    } catch (e) {
      return UserStatisticsResult.failure(
        message: 'An unexpected error occurred',
      );
    }
  }

  /// Get user's saved routes
  Future<UserRoutesResult> getUserRoutes(
    String userId, {
    required String accessToken,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final routes = await _apiClient.getUserRoutes(
        userId,
        accessToken: accessToken,
        page: page,
        size: size,
      );
      return UserRoutesResult.success(routes: routes);
    } on DioException catch (e) {
      // Handle 404 as "no routes" - not an error
      if (e.response?.statusCode == 404) {
        return UserRoutesResult.success(routes: []);
      }
      final result = _handleDioException(e, 'Failed to fetch routes');
      return UserRoutesResult.failure(message: result.message);
    } catch (e) {
      return UserRoutesResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Get user's run sessions
  Future<UserRunsResult> getUserRunSessions(
    String userId, {
    required String accessToken,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final runs = await _apiClient.getUserRunSessions(
        userId,
        accessToken: accessToken,
        page: page,
        size: size,
      );
      return UserRunsResult.success(runs: runs);
    } on DioException catch (e) {
      // Handle 404 as "no runs" - not an error
      if (e.response?.statusCode == 404) {
        return UserRunsResult.success(runs: []);
      }
      final result = _handleDioException(e, 'Failed to fetch run sessions');
      return UserRunsResult.failure(message: result.message);
    } catch (e) {
      return UserRunsResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Get user's feed posts
  Future<UserPostsResult> getUserPosts(
    String userId, {
    required String accessToken,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final posts = await _apiClient.getUserPosts(
        userId,
        accessToken: accessToken,
        page: page,
        size: size,
      );
      return UserPostsResult.success(posts: posts);
    } on DioException catch (e) {
      // Handle 404 as "no posts" - not an error
      if (e.response?.statusCode == 404) {
        return UserPostsResult.success(posts: []);
      }
      final result = _handleDioException(e, 'Failed to fetch posts');
      return UserPostsResult.failure(message: result.message);
    } catch (e) {
      return UserPostsResult.failure(message: 'An unexpected error occurred');
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
  ProfilePictureResult _handlePictureDioException(
    DioException e,
    String defaultMessage,
  ) {
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
    return ProfileResult._(success: true, message: message, profile: profile);
  }

  factory ProfileResult.failure({required String message}) {
    return ProfileResult._(success: false, message: message);
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

  factory ProfilePictureResult.failure({required String message}) {
    return ProfilePictureResult._(success: false, message: message);
  }
}

/// All profiles result wrapper
class AllProfilesResult {
  final bool success;
  final String message;
  final List<UserProfile> profiles;
  final int totalElements;
  final int totalPages;
  final bool hasMore;

  const AllProfilesResult._({
    required this.success,
    required this.message,
    this.profiles = const [],
    this.totalElements = 0,
    this.totalPages = 0,
    this.hasMore = false,
  });

  factory AllProfilesResult.success({
    required List<UserProfile> profiles,
    int totalElements = 0,
    int totalPages = 0,
    bool hasMore = false,
    String message = 'Success',
  }) {
    return AllProfilesResult._(
      success: true,
      message: message,
      profiles: profiles,
      totalElements: totalElements,
      totalPages: totalPages,
      hasMore: hasMore,
    );
  }

  factory AllProfilesResult.failure({required String message}) {
    return AllProfilesResult._(success: false, message: message);
  }
}

/// User statistics result wrapper
class UserStatisticsResult {
  final bool success;
  final String message;
  final UserStatistics? statistics;

  const UserStatisticsResult._({
    required this.success,
    required this.message,
    this.statistics,
  });

  factory UserStatisticsResult.success({
    required UserStatistics statistics,
    String message = 'Success',
  }) {
    return UserStatisticsResult._(
      success: true,
      message: message,
      statistics: statistics,
    );
  }

  factory UserStatisticsResult.failure({required String message}) {
    return UserStatisticsResult._(success: false, message: message);
  }
}

/// User routes result wrapper
class UserRoutesResult {
  final bool success;
  final String message;
  final List<RouteDto> routes;

  const UserRoutesResult._({
    required this.success,
    required this.message,
    this.routes = const [],
  });

  factory UserRoutesResult.success({
    required List<RouteDto> routes,
    String message = 'Success',
  }) {
    return UserRoutesResult._(success: true, message: message, routes: routes);
  }

  factory UserRoutesResult.failure({required String message}) {
    return UserRoutesResult._(success: false, message: message);
  }
}

/// User run sessions result wrapper
class UserRunsResult {
  final bool success;
  final String message;
  final List<RunSession> runs;

  const UserRunsResult._({
    required this.success,
    required this.message,
    this.runs = const [],
  });

  factory UserRunsResult.success({
    required List<RunSession> runs,
    String message = 'Success',
  }) {
    return UserRunsResult._(success: true, message: message, runs: runs);
  }

  factory UserRunsResult.failure({required String message}) {
    return UserRunsResult._(success: false, message: message);
  }
}

/// User posts result wrapper
class UserPostsResult {
  final bool success;
  final String message;
  final List<FeedPostDto> posts;

  const UserPostsResult._({
    required this.success,
    required this.message,
    this.posts = const [],
  });

  factory UserPostsResult.success({
    required List<FeedPostDto> posts,
    String message = 'Success',
  }) {
    return UserPostsResult._(success: true, message: message, posts: posts);
  }

  factory UserPostsResult.failure({required String message}) {
    return UserPostsResult._(success: false, message: message);
  }
}
