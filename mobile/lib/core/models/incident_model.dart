import 'enums.dart';

class IncidentModel {
  final String id;
  final String relationshipId;
  final String monitoredUserId;
  final IncidentStatus status;
  final IncidentReason reason;
  final int riskScore;
  final DateTime triggeredAt;
  final DateTime? escalatedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByUserId;
  final DateTime? resolvedAt;
  final String? resolvedByUserId;
  final String? resolutionNote;
  final List<dynamic>? events;
  final String? userDisplayName;

  IncidentModel({
    required this.id,
    required this.relationshipId,
    required this.monitoredUserId,
    required this.status,
    required this.reason,
    required this.riskScore,
    required this.triggeredAt,
    this.escalatedAt,
    this.acknowledgedAt,
    this.acknowledgedByUserId,
    this.resolvedAt,
    this.resolvedByUserId,
    this.resolutionNote,
    this.events,
    this.userDisplayName,
  });

  String? get note => resolutionNote;
  DateTime get detectedAt => triggeredAt;

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    final str = val.toString().trim();
    if (str.isEmpty) return null;
    final asInt = int.tryParse(str);
    if (asInt != null && asInt > 10000000000) {
      return DateTime.fromMillisecondsSinceEpoch(asInt);
    }
    return DateTime.tryParse(str);
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString());
  }

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];
    return IncidentModel(
      id: json['id']?.toString() ?? '',
      relationshipId: json['relationshipId']?.toString() ??
          json['relationship_id']?.toString() ??
          '',
      monitoredUserId: json['userId']?.toString() ??
          json['user_id']?.toString() ??
          json['monitoredUserId']?.toString() ??
          json['monitored_user_id']?.toString() ??
          '',
      status: IncidentStatus.fromString(json['status']?.toString()),
      reason: IncidentReason.fromString(json['reason']?.toString()),
      riskScore: _parseInt(json['riskScore'] ?? json['risk_score']) ?? 50,
      triggeredAt: _parseDate(
            json['detectedAt'] ??
                json['detected_at'] ??
                json['triggeredAt'] ??
                json['triggered_at'],
          ) ??
          DateTime.now(),
      escalatedAt: _parseDate(json['escalatedAt'] ?? json['escalated_at']),
      acknowledgedAt:
          _parseDate(json['acknowledgedAt'] ?? json['acknowledged_at']),
      acknowledgedByUserId: json['acknowledgedBy']?.toString() ??
          json['acknowledged_by']?.toString() ??
          json['acknowledgedByUserId']?.toString() ??
          json['acknowledged_by_user_id']?.toString(),
      resolvedAt: _parseDate(json['resolvedAt'] ?? json['resolved_at']),
      resolvedByUserId: json['resolvedBy']?.toString() ??
          json['resolved_by']?.toString() ??
          json['resolvedByUserId']?.toString() ??
          json['resolved_by_user_id']?.toString(),
      resolutionNote: json['note']?.toString() ??
          json['resolutionNote']?.toString() ??
          json['resolution_note']?.toString(),
      events: rawEvents is List ? rawEvents : null,
      userDisplayName: json['userDisplayName']?.toString() ??
          (json['user'] is Map ? (json['user']['displayName'] ?? json['user']['fullName'])?.toString() : null) ??
          json['userName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'relationshipId': relationshipId,
      'monitoredUserId': monitoredUserId,
      'status': status.name,
      'reason': reason.name,
      'riskScore': riskScore,
      'triggeredAt': triggeredAt.toIso8601String(),
      'detectedAt': triggeredAt.toIso8601String(),
      if (escalatedAt != null) 'escalatedAt': escalatedAt!.toIso8601String(),
      if (acknowledgedAt != null)
        'acknowledgedAt': acknowledgedAt!.toIso8601String(),
      if (acknowledgedByUserId != null)
        'acknowledgedByUserId': acknowledgedByUserId,
      if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
      if (resolvedByUserId != null) 'resolvedByUserId': resolvedByUserId,
      if (resolutionNote != null) 'resolutionNote': resolutionNote,
      if (resolutionNote != null) 'note': resolutionNote,
      if (events != null) 'events': events,
      if (userDisplayName != null) 'userDisplayName': userDisplayName,
    };
  }

  IncidentModel copyWith({
    String? id,
    String? relationshipId,
    String? monitoredUserId,
    IncidentStatus? status,
    IncidentReason? reason,
    int? riskScore,
    DateTime? triggeredAt,
    DateTime? escalatedAt,
    DateTime? acknowledgedAt,
    String? acknowledgedByUserId,
    DateTime? resolvedAt,
    String? resolvedByUserId,
    String? resolutionNote,
    List<dynamic>? events,
    String? userDisplayName,
  }) {
    return IncidentModel(
      id: id ?? this.id,
      relationshipId: relationshipId ?? this.relationshipId,
      monitoredUserId: monitoredUserId ?? this.monitoredUserId,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      riskScore: riskScore ?? this.riskScore,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      escalatedAt: escalatedAt ?? this.escalatedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedByUserId: acknowledgedByUserId ?? this.acknowledgedByUserId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedByUserId: resolvedByUserId ?? this.resolvedByUserId,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      events: events ?? this.events,
      userDisplayName: userDisplayName ?? this.userDisplayName,
    );
  }
}
