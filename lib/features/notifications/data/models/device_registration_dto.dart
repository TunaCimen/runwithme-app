/// Platform type for device registration
enum DevicePlatform {
  android('ANDROID'),
  ios('IOS'),
  web('WEB');

  final String value;
  const DevicePlatform(this.value);

  String toJson() => value;

  static DevicePlatform fromJson(String json) {
    return DevicePlatform.values.firstWhere(
      (e) => e.value == json,
      orElse: () => DevicePlatform.android,
    );
  }
}

/// Request DTO for registering a device for push notifications
class DeviceRegistrationRequestDto {
  final String token;
  final DevicePlatform platform;
  final String? deviceName;

  DeviceRegistrationRequestDto({
    required this.token,
    required this.platform,
    this.deviceName,
  });

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'platform': platform.toJson(),
      if (deviceName != null) 'deviceName': deviceName,
    };
  }
}

/// Response DTO for device registration
class DeviceRegistrationResponseDto {
  final int? id;
  final String token;
  final String platform;
  final String? deviceName;
  final String? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeviceRegistrationResponseDto({
    this.id,
    required this.token,
    required this.platform,
    this.deviceName,
    this.userId,
    this.createdAt,
    this.updatedAt,
  });

  factory DeviceRegistrationResponseDto.fromJson(Map<String, dynamic> json) {
    return DeviceRegistrationResponseDto(
      id: json['id'] as int?,
      token: json['token'] as String,
      platform: json['platform'] as String,
      deviceName: json['deviceName'] as String?,
      userId: json['userId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
