import 'enums.dart';
import 'user_model.dart';
import 'monitoring_config_model.dart';

class RelationshipModel {
  final String id;
  final String monitoredUserId;
  final String monitorUserId;
  final RelationshipStatus status;
  final String? inviteCode;
  final String? label;
  final UserModel? monitoredUser;
  final UserModel? monitorUser;
  final MonitoringConfigModel? config;
  final DateTime createdAt;

  RelationshipModel({
    required this.id,
    required this.monitoredUserId,
    required this.monitorUserId,
    required this.status,
    this.inviteCode,
    this.label,
    this.monitoredUser,
    this.monitorUser,
    this.config,
    required this.createdAt,
  });

  String get monitorId => monitorUserId;
  String? get invitationCode => inviteCode;

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    final str = val.toString().trim();
    if (str.isEmpty) return DateTime.now();
    final asInt = int.tryParse(str);
    if (asInt != null && asInt > 10000000000) {
      return DateTime.fromMillisecondsSinceEpoch(asInt);
    }
    return DateTime.tryParse(str) ?? DateTime.now();
  }

  factory RelationshipModel.fromJson(Map<String, dynamic> json) {
    final rawMonitoredUser = json['monitoredUser'] ?? json['monitored'];
    final rawMonitorUser = json['monitorUser'] ?? json['monitor'];
    final rawConfig = json['config'];

    return RelationshipModel(
      id: json['id']?.toString() ?? '',
      monitoredUserId: json['monitoredUserId']?.toString() ??
          json['monitored_user_id']?.toString() ??
          (rawMonitoredUser is Map ? rawMonitoredUser['id']?.toString() : null) ??
          '',
      monitorUserId: json['monitorId']?.toString() ??
          json['monitor_id']?.toString() ??
          json['monitorUserId']?.toString() ??
          json['monitor_user_id']?.toString() ??
          (rawMonitorUser is Map ? rawMonitorUser['id']?.toString() : null) ??
          '',
      status: RelationshipStatus.fromString(json['status']?.toString()),
      inviteCode: json['invitationCode']?.toString() ??
          json['invitation_code']?.toString() ??
          json['inviteCode']?.toString() ??
          json['invite_code']?.toString(),
      label: json['label']?.toString(),
      monitoredUser: rawMonitoredUser is Map
          ? UserModel.fromJson(Map<String, dynamic>.from(rawMonitoredUser))
          : null,
      monitorUser: rawMonitorUser is Map
          ? UserModel.fromJson(Map<String, dynamic>.from(rawMonitorUser))
          : null,
      config: rawConfig is Map
          ? MonitoringConfigModel.fromJson(Map<String, dynamic>.from(rawConfig))
          : null,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'monitoredUserId': monitoredUserId,
      'monitorUserId': monitorUserId,
      'status': status.name,
      if (inviteCode != null) 'inviteCode': inviteCode,
      if (inviteCode != null) 'invitationCode': inviteCode,
      if (label != null) 'label': label,
      if (monitoredUser != null) 'monitoredUser': monitoredUser!.toJson(),
      if (monitorUser != null) 'monitorUser': monitorUser!.toJson(),
      if (config != null) 'config': config!.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  RelationshipModel copyWith({
    String? id,
    String? monitoredUserId,
    String? monitorUserId,
    RelationshipStatus? status,
    String? inviteCode,
    String? label,
    UserModel? monitoredUser,
    UserModel? monitorUser,
    MonitoringConfigModel? config,
    DateTime? createdAt,
  }) {
    return RelationshipModel(
      id: id ?? this.id,
      monitoredUserId: monitoredUserId ?? this.monitoredUserId,
      monitorUserId: monitorUserId ?? this.monitorUserId,
      status: status ?? this.status,
      inviteCode: inviteCode ?? this.inviteCode,
      label: label ?? this.label,
      monitoredUser: monitoredUser ?? this.monitoredUser,
      monitorUser: monitorUser ?? this.monitorUser,
      config: config ?? this.config,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
