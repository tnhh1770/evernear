import 'enums.dart';

class DeviceModel {
  final String id;
  final String userId;
  final DevicePlatform platform;
  final String? deviceModel;
  final String? osVersion;
  final String? appVersion;
  final String? fcmToken;
  final int? batteryLevel;
  final bool? isCharging;
  final bool isActive;
  final DateTime? lastHeartbeatAt;
  final DateTime createdAt;

  DeviceModel({
    required this.id,
    required this.userId,
    required this.platform,
    this.deviceModel,
    this.osVersion,
    this.appVersion,
    this.fcmToken,
    this.batteryLevel,
    this.isCharging,
    required this.isActive,
    this.lastHeartbeatAt,
    required this.createdAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      platform: DevicePlatform.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['platform'] as String? ?? '').toLowerCase(),
        orElse: () => DevicePlatform.ANDROID,
      ),
      deviceModel: json['deviceModel'] as String? ?? json['device_model'] as String?,
      osVersion: json['osVersion'] as String? ?? json['os_version'] as String?,
      appVersion: json['appVersion'] as String? ?? json['app_version'] as String?,
      fcmToken: json['fcmToken'] as String? ??
          json['pushToken'] as String? ??
          json['push_token'] as String? ??
          json['fcm_token'] as String?,
      batteryLevel: json['batteryLevel'] as int? ?? json['battery_level'] as int?,
      isCharging: json['isCharging'] as bool? ?? json['is_charging'] as bool?,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      lastHeartbeatAt: json['lastHeartbeatAt'] != null || json['last_heartbeat_at'] != null
          ? DateTime.tryParse((json['lastHeartbeatAt'] ?? json['last_heartbeat_at']).toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
