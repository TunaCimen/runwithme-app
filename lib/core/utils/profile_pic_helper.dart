/// Helper class for profile picture URL handling
class ProfilePicHelper {
  static const String _baseUrl = 'http://35.158.35.102:8080';

  /// Get the full URL for a profile picture filename
  /// Returns null if filename is null or empty
  static String? getProfilePicUrl(String? filename) {
    if (filename == null || filename.isEmpty) return null;

    // If it's already a full URL, return as is
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }

    // Otherwise, construct the URL
    return '$_baseUrl/api/v1/images/profile-pictures/$filename';
  }
}
