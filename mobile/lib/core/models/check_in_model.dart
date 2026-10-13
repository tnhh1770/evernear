import 'user_model.dart';

class CheckInModel {
  final String id;
  final String userId;
  final String? relationshipId;
  final String? deviceId;
  final DateTime occurredAt;
  final int? batteryLevel;
  final String? note;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final UserModel? user;
  final String? userDisplayName;

  CheckInModel({
    required this.id,
    required this.userId,
    this.relationshipId,
    this.deviceId,
    required this.occurredAt,
    this.batteryLevel,
    this.note,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.user,
    this.userDisplayName,
  });

  String get displayName =>
      userDisplayName ?? user?.fullName ?? '';

  factory CheckInModel.fromJson(Map<String, dynamic> json) {
    UserModel? parsedUser;
    if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      parsedUser = UserModel.fromJson(json['user'] as Map<String, dynamic>);
    }

    return CheckInModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      relationshipId: json['relationshipId'] as String? ?? json['relationship_id'] as String?,
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String?,
      occurredAt: json['occurredAt'] != null || json['occurred_at'] != null
          ? DateTime.parse((json['occurredAt'] ?? json['occurred_at']) as String)
          : DateTime.now(),
      batteryLevel: json['batteryLevel'] as int? ?? json['battery_level'] as int?,
      note: json['note'] as String?,
      latitude: json['location'] != null
          ? (json['location']['latitude'] as num?)?.toDouble()
          : (json['latitude'] as num?)?.toDouble(),
      longitude: json['location'] != null
          ? (json['location']['longitude'] as num?)?.toDouble()
          : (json['longitude'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      user: parsedUser,
      userDisplayName: json['userDisplayName'] as String? ?? parsedUser?.fullName,
    );
  }
}
