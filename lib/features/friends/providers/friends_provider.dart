import 'package:flutter/foundation.dart';
import '../data/friends_repository.dart';
import '../data/friends_api_client.dart';
import '../data/models/friend_request_dto.dart';
import '../data/models/friendship_dto.dart';
import '../../profile/data/profile_repository.dart';
import '../../../core/models/user_profile.dart';

// Debug flag
const bool _debugFriends = true;
void _log(String message) {
  if (_debugFriends) {
    debugPrint('[FriendsProvider] $message');
  }
}

/// Provider for managing friends state
class FriendsProvider extends ChangeNotifier {
  final FriendsRepository _repository;
  final ProfileRepository _profileRepository;

  // Cache for user profiles
  final Map<String, UserProfile> _profileCache = {};
  String? _authToken;
  String? _currentUserId;

  // Friends list state
  List<FriendshipDto> _friends = [];
  bool _friendsLoading = false;
  bool _friendsHasMore = true;
  int _friendsPage = 0;
  String? _friendsError;

  // Sent requests state
  List<FriendRequestDto> _sentRequests = [];
  bool _sentRequestsLoading = false;
  bool _sentRequestsHasMore = true;
  int _sentRequestsPage = 0;
  String? _sentRequestsError;

  // Received requests state
  List<FriendRequestDto> _receivedRequests = [];
  bool _receivedRequestsLoading = false;
  bool _receivedRequestsHasMore = true;
  int _receivedRequestsPage = 0;
  String? _receivedRequestsError;

  // Action loading states
  bool _sendingRequest = false;
  bool _respondingToRequest = false;
  bool _removingFriend = false;

  FriendsProvider({
    String baseUrl = 'http://35.158.35.102:8080',
    FriendsRepository? repository,
    ProfileRepository? profileRepository,
  }) : _repository = repository ?? FriendsRepository(baseUrl: baseUrl),
       _profileRepository = profileRepository ?? ProfileRepository(baseUrl: baseUrl);

  // Getters
  List<FriendshipDto> get friends => _friends;
  bool get friendsLoading => _friendsLoading;
  bool get friendsHasMore => _friendsHasMore;
  String? get friendsError => _friendsError;

  List<FriendRequestDto> get sentRequests => _sentRequests;
  bool get sentRequestsLoading => _sentRequestsLoading;
  bool get sentRequestsHasMore => _sentRequestsHasMore;
  String? get sentRequestsError => _sentRequestsError;

  List<FriendRequestDto> get receivedRequests => _receivedRequests;
  bool get receivedRequestsLoading => _receivedRequestsLoading;
  bool get receivedRequestsHasMore => _receivedRequestsHasMore;
  String? get receivedRequestsError => _receivedRequestsError;

  bool get sendingRequest => _sendingRequest;
  bool get respondingToRequest => _respondingToRequest;
  bool get removingFriend => _removingFriend;

  int get receivedRequestsCount => _receivedRequests.length;

  /// Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
    _repository.setAuthToken(token);
  }

  /// Set current user ID for enrichment
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// Fetch user profile and cache it
  Future<UserProfile?> _fetchAndCacheProfile(String userId) async {
    _log('_fetchAndCacheProfile called for userId: $userId');

    if (_profileCache.containsKey(userId)) {
      _log('  -> Found in cache: ${_profileCache[userId]?.firstName} ${_profileCache[userId]?.lastName}');
      return _profileCache[userId];
    }

    if (_authToken == null) {
      _log('  -> ERROR: No auth token!');
      return null;
    }

    try {
      _log('  -> Fetching profile from API...');
      final result = await _profileRepository.getProfile(userId, accessToken: _authToken!);
      _log('  -> API result: success=${result.success}, profile=${result.profile}');
      if (result.success && result.profile != null) {
        _log('  -> Got profile: firstName=${result.profile!.firstName}, lastName=${result.profile!.lastName}');
        _profileCache[userId] = result.profile!;
        return result.profile;
      } else {
        _log('  -> Profile fetch failed: ${result.message}');
      }
    } catch (e) {
      _log('  -> Exception fetching profile: $e');
    }
    return null;
  }

  /// Enrich friend requests with profile data
  Future<List<FriendRequestDto>> _enrichFriendRequests(
    List<FriendRequestDto> requests,
    {required bool isSent}
  ) async {
    _log('_enrichFriendRequests called: ${requests.length} requests, isSent=$isSent');
    final enrichedRequests = <FriendRequestDto>[];

    for (final request in requests) {
      // For sent requests, we need receiver info; for received, we need sender info
      final userId = isSent ? request.receiverId : request.senderId;
      _log('  Processing request ${request.requestId}: userId=$userId');
      _log('    Before enrich - senderUsername: ${request.senderUsername}, receiverUsername: ${request.receiverUsername}');

      final profile = await _fetchAndCacheProfile(userId);

      if (profile != null) {
        _log('    Got profile: ${profile.firstName} ${profile.lastName}');
        if (isSent) {
          final enriched = request.copyWith(
            receiverUsername: profile.firstName ?? profile.lastName ?? 'User',
            receiverFirstName: profile.firstName,
            receiverLastName: profile.lastName,
            receiverProfilePic: profile.profilePic,
          );
          _log('    After enrich - receiverDisplayName: ${enriched.receiverDisplayName}');
          enrichedRequests.add(enriched);
        } else {
          final enriched = request.copyWith(
            senderUsername: profile.firstName ?? profile.lastName ?? 'User',
            senderFirstName: profile.firstName,
            senderLastName: profile.lastName,
            senderProfilePic: profile.profilePic,
          );
          _log('    After enrich - senderDisplayName: ${enriched.senderDisplayName}');
          enrichedRequests.add(enriched);
        }
      } else {
        _log('    No profile found, keeping original request');
        enrichedRequests.add(request);
      }
    }

    _log('  Enrichment complete: ${enrichedRequests.length} requests');
    return enrichedRequests;
  }

  /// Get cached profile
  UserProfile? getCachedProfile(String userId) => _profileCache[userId];

  /// Enrich friendships with profile data (profile pics)
  Future<List<FriendshipDto>> _enrichFriendships(List<FriendshipDto> friendships) async {
    _log('_enrichFriendships called: ${friendships.length} friendships');
    final enrichedFriendships = <FriendshipDto>[];

    for (final friendship in friendships) {
      final userId = friendship.friendUserId;
      _log('  Processing friendship: friendUserId=$userId, existing profilePic=${friendship.friendProfilePic}');

      // Only fetch profile if we don't have profile pic
      if (friendship.friendProfilePic == null || friendship.friendProfilePic!.isEmpty) {
        final profile = await _fetchAndCacheProfile(userId);

        if (profile != null && profile.profilePic != null) {
          _log('    Got profile pic: ${profile.profilePic}');
          final enriched = friendship.copyWith(
            friendProfilePic: profile.profilePic,
            friendFirstName: profile.firstName ?? friendship.friendFirstName,
            friendLastName: profile.lastName ?? friendship.friendLastName,
          );
          enrichedFriendships.add(enriched);
        } else {
          _log('    No profile pic found');
          enrichedFriendships.add(friendship);
        }
      } else {
        _log('    Already has profile pic');
        enrichedFriendships.add(friendship);
      }
    }

    _log('  Enrichment complete: ${enrichedFriendships.length} friendships');
    return enrichedFriendships;
  }

  /// Load friends list (initial load or refresh)
  Future<void> loadFriends({bool refresh = false}) async {
    _log('loadFriends called: refresh=$refresh, authToken=${_authToken != null ? "present" : "null"}, currentUserId=$_currentUserId');

    if (_friendsLoading) {
      _log('  -> Already loading, skipping');
      return;
    }

    if (refresh) {
      _friendsPage = 0;
      _friendsHasMore = true;
    }

    _friendsLoading = true;
    _friendsError = null;
    notifyListeners();

    final result = await _repository.getFriends(page: _friendsPage);
    _log('  API result: success=${result.success}, content=${result.data?.content.length ?? 0} items');

    if (result.success && result.data != null) {
      // The API returns friend info in a nested "user" object
      List<FriendshipDto> friendships = result.data!.content;

      // Log friendship data
      for (final f in friendships) {
        _log('    Friendship: friendUserId=${f.friendUserId}, friendUsername=${f.friendUsername}, profilePic=${f.friendProfilePic}');
        final displayName = f.getFriendDisplayName(_currentUserId ?? '');
        _log('      -> displayName=$displayName');
      }

      // Enrich with profile data (including profile pics)
      friendships = await _enrichFriendships(friendships);

      if (refresh) {
        _friends = friendships;
      } else {
        _friends = [..._friends, ...friendships];
      }
      _friendsHasMore = !result.data!.last;
      _friendsPage++;
    } else {
      _log('  -> Failed: ${result.message}');
      _friendsError = result.message;
    }

    _friendsLoading = false;
    _log('  Final friends count: ${_friends.length}');
    notifyListeners();
  }

  /// Load more friends (pagination)
  Future<void> loadMoreFriends() async {
    if (!_friendsHasMore || _friendsLoading) return;
    await loadFriends();
  }

  /// Load sent requests (initial load or refresh)
  Future<void> loadSentRequests({bool refresh = false}) async {
    _log('loadSentRequests called: refresh=$refresh, authToken=${_authToken != null ? "present" : "null"}');

    if (_sentRequestsLoading) {
      _log('  -> Already loading, skipping');
      return;
    }

    if (refresh) {
      _sentRequestsPage = 0;
      _sentRequestsHasMore = true;
    }

    _sentRequestsLoading = true;
    _sentRequestsError = null;
    notifyListeners();

    final result = await _repository.getSentRequests(page: _sentRequestsPage);
    _log('  API result: success=${result.success}, content=${result.data?.content.length ?? 0} items');

    if (result.success && result.data != null) {
      var pendingRequests = result.data!.content
          .where((r) => r.status == FriendRequestStatus.pending)
          .toList();
      _log('  Pending requests: ${pendingRequests.length}');

      // Log raw request data
      for (final req in pendingRequests) {
        _log('    Raw request: id=${req.requestId}, receiverId=${req.receiverId}, receiverUsername=${req.receiverUsername}');
      }

      // Enrich with receiver profile data
      pendingRequests = await _enrichFriendRequests(pendingRequests, isSent: true);

      // Log enriched request data
      for (final req in pendingRequests) {
        _log('    Enriched request: id=${req.requestId}, receiverDisplayName=${req.receiverDisplayName}');
      }

      if (refresh) {
        _sentRequests = pendingRequests;
      } else {
        _sentRequests = [..._sentRequests, ...pendingRequests];
      }
      _sentRequestsHasMore = !result.data!.last;
      _sentRequestsPage++;
    } else {
      _log('  -> Failed: ${result.message}');
      _sentRequestsError = result.message;
    }

    _sentRequestsLoading = false;
    notifyListeners();
  }

  /// Load more sent requests (pagination)
  Future<void> loadMoreSentRequests() async {
    if (!_sentRequestsHasMore || _sentRequestsLoading) return;
    await loadSentRequests();
  }

  /// Load received requests (initial load or refresh)
  Future<void> loadReceivedRequests({bool refresh = false}) async {
    _log('loadReceivedRequests called: refresh=$refresh, authToken=${_authToken != null ? "present" : "null"}');

    if (_receivedRequestsLoading) {
      _log('  -> Already loading, skipping');
      return;
    }

    if (refresh) {
      _receivedRequestsPage = 0;
      _receivedRequestsHasMore = true;
    }

    _receivedRequestsLoading = true;
    _receivedRequestsError = null;
    notifyListeners();

    final result = await _repository.getReceivedRequests(page: _receivedRequestsPage);
    _log('  API result: success=${result.success}, content=${result.data?.content.length ?? 0} items');

    if (result.success && result.data != null) {
      var pendingRequests = result.data!.content
          .where((r) => r.status == FriendRequestStatus.pending)
          .toList();
      _log('  Pending requests: ${pendingRequests.length}');

      // Log raw request data
      for (final req in pendingRequests) {
        _log('    Raw request: id=${req.requestId}, senderId=${req.senderId}, senderUsername=${req.senderUsername}');
      }

      // Enrich with sender profile data
      pendingRequests = await _enrichFriendRequests(pendingRequests, isSent: false);

      // Log enriched request data
      for (final req in pendingRequests) {
        _log('    Enriched request: id=${req.requestId}, senderDisplayName=${req.senderDisplayName}');
      }

      if (refresh) {
        _receivedRequests = pendingRequests;
      } else {
        _receivedRequests = [..._receivedRequests, ...pendingRequests];
      }
      _receivedRequestsHasMore = !result.data!.last;
      _receivedRequestsPage++;
    } else {
      _log('  -> Failed: ${result.message}');
      _receivedRequestsError = result.message;
    }

    _receivedRequestsLoading = false;
    notifyListeners();
  }

  /// Load more received requests (pagination)
  Future<void> loadMoreReceivedRequests() async {
    if (!_receivedRequestsHasMore || _receivedRequestsLoading) return;
    await loadReceivedRequests();
  }

  /// Load all data (friends, sent requests, received requests)
  Future<void> loadAll() async {
    await Future.wait([
      loadFriends(refresh: true),
      loadSentRequests(refresh: true),
      loadReceivedRequests(refresh: true),
    ]);
  }

  /// Send a friend request
  Future<FriendsResult<FriendRequestDto>> sendRequest({
    required String receiverId,
    String? message,
  }) async {
    _sendingRequest = true;
    notifyListeners();

    final result = await _repository.sendFriendRequest(
      receiverId: receiverId,
      message: message,
    );

    if (result.success && result.data != null) {
      // Enrich the new request with receiver profile data
      final enriched = await _enrichFriendRequests([result.data!], isSent: true);
      _sentRequests = [...enriched, ..._sentRequests];
    }

    _sendingRequest = false;
    notifyListeners();

    return result;
  }

  /// Accept a friend request
  Future<FriendsResult<FriendRequestDto>> acceptRequest(String requestId) async {
    _log('acceptRequest called: requestId=$requestId');
    _respondingToRequest = true;
    notifyListeners();

    final result = await _repository.acceptRequest(requestId);
    _log('  API result: success=${result.success}, message=${result.message}');

    if (result.success) {
      _log('  Removing request from received list...');
      // Remove from received requests
      _receivedRequests.removeWhere((r) => r.requestId == requestId);
      _log('  Refreshing friends list...');
      // Refresh friends list to include new friend
      await loadFriends(refresh: true);
      _log('  Friends list refreshed, count: ${_friends.length}');
    } else {
      _log('  Accept failed: ${result.message}');
    }

    _respondingToRequest = false;
    notifyListeners();

    return result;
  }

  /// Reject a friend request
  Future<FriendsResult<FriendRequestDto>> rejectRequest(String requestId) async {
    _respondingToRequest = true;
    notifyListeners();

    final result = await _repository.rejectRequest(requestId);

    if (result.success) {
      _receivedRequests.removeWhere((r) => r.requestId == requestId);
    }

    _respondingToRequest = false;
    notifyListeners();

    return result;
  }

  /// Cancel a sent friend request
  Future<FriendsResult<void>> cancelRequest(String requestId) async {
    _sendingRequest = true;
    notifyListeners();

    final result = await _repository.cancelRequest(requestId);

    if (result.success) {
      _sentRequests.removeWhere((r) => r.requestId == requestId);
    }

    _sendingRequest = false;
    notifyListeners();

    return result;
  }

  /// Remove a friend
  Future<FriendsResult<void>> removeFriend(String friendshipId) async {
    _removingFriend = true;
    notifyListeners();

    final result = await _repository.removeFriend(friendshipId);

    if (result.success) {
      _friends.removeWhere((f) => f.friendshipId == friendshipId);
    }

    _removingFriend = false;
    notifyListeners();

    return result;
  }

  /// Check friendship status with another user
  Future<FriendshipStatusDto?> checkFriendshipStatus(String otherUserId) async {
    final result = await _repository.checkFriendshipStatus(otherUserId);
    return result.success ? result.data : null;
  }

  /// Check if a user is a friend
  bool isFriend(String userId) {
    return _friends.any((f) => f.friendUserId == userId);
  }

  /// Check if there's a pending sent request to a user
  bool hasPendingSentRequest(String userId) {
    return _sentRequests.any((r) => r.receiverId == userId);
  }

  /// Check if there's a pending received request from a user
  bool hasPendingReceivedRequest(String userId) {
    return _receivedRequests.any((r) => r.senderId == userId);
  }

  /// Clear all data (for logout)
  void clear() {
    _friends = [];
    _friendsLoading = false;
    _friendsHasMore = true;
    _friendsPage = 0;
    _friendsError = null;

    _sentRequests = [];
    _sentRequestsLoading = false;
    _sentRequestsHasMore = true;
    _sentRequestsPage = 0;
    _sentRequestsError = null;

    _receivedRequests = [];
    _receivedRequestsLoading = false;
    _receivedRequestsHasMore = true;
    _receivedRequestsPage = 0;
    _receivedRequestsError = null;

    _profileCache.clear();
    _authToken = null;
    _currentUserId = null;

    notifyListeners();
  }
}
