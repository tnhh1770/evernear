import 'enums.dart';
import 'schedule_window_model.dart';

class MonitoringConfigModel {
  final String id;
  final String relationshipId;
  final MonitoringState currentState;
  final int inactivityThresholdMinutes;
  final int checkInGracePeriodMinutes;
  final int escalationGracePeriodMinutes;
  final bool locationEnabled;
  final bool isPaused;
  final DateTime? pausedUntil;
  final DateTime? lastMeaningfulActivityAt;
  final DateTime? checkInRequestedAt;
  final DateTime? gracePeriodStartedAt;
  final DateTime? alertTriggeredAt;
  final DateTime? nextEvaluationAt;
  final List<ScheduleWindowModel> scheduleWindows;
  final String timezone;
  final bool enabled;

  MonitoringConfigModel({
    required this.id,
    required this.relationshipId,
    required this.currentState,
    required this.inactivityThresholdMinutes,
    required this.checkInGracePeriodMinutes,
    required this.escalationGracePeriodMinutes,
    required this.locationEnabled,
    required this.isPaused,
    this.pausedUntil,
    this.lastMeaningfulActivityAt,
    this.checkInRequestedAt,
    this.gracePeriodStartedAt,
    this.alertTriggeredAt,
    this.nextEvaluationAt,
    this.scheduleWindows = const [],
    this.timezone = 'Asia/Ho_Chi_Minh',
    this.enabled = true,
  });

  /// Backend compatibility alias
  int get checkInGraceMinutes => checkInGracePeriodMinutes;

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

  factory MonitoringConfigModel.fromJson(Map<String, dynamic> json) {
    final rawWindows = json['scheduleWindows'] ??
        json['schedule_windows'] ??
        json['windows'];
    final List<ScheduleWindowModel> windows = [];
    if (rawWindows is List) {
      for (final item in rawWindows) {
        if (item is Map) {
          windows.add(ScheduleWindowModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return MonitoringConfigModel(
      id: json['id']?.toString() ?? '',
      relationshipId: json['relationshipId']?.toString() ??
          json['relationship_id']?.toString() ??
          '',
      currentState: MonitoringState.fromString(
        (json['currentState'] ?? json['current_state'])?.toString(),
      ),
      inactivityThresholdMinutes: _parseInt(
            json['inactivityThresholdMinutes'] ??
                json['inactivity_threshold_minutes'],
          ) ??
          180,
      checkInGracePeriodMinutes: _parseInt(
            json['checkInGraceMinutes'] ??
                json['check_in_grace_minutes'] ??
                json['checkInGracePeriodMinutes'] ??
                json['check_in_grace_period_minutes'],
          ) ??
          30,
      escalationGracePeriodMinutes: _parseInt(
            json['escalationGracePeriodMinutes'] ??
                json['escalation_grace_period_minutes'],
          ) ??
          30,
      locationEnabled: json['locationEnabled'] as bool? ??
          json['location_enabled'] as bool? ??
          true,
      isPaused: json['isPaused'] as bool? ?? json['is_paused'] as bool? ?? false,
      pausedUntil: _parseDate(json['pausedUntil'] ?? json['paused_until']),
      lastMeaningfulActivityAt: _parseDate(
          json['lastMeaningfulActivityAt'] ?? json['last_meaningful_activity_at']),
      checkInRequestedAt: _parseDate(
          json['checkInRequestedAt'] ?? json['check_in_requested_at']),
      gracePeriodStartedAt: _parseDate(
          json['gracePeriodStartedAt'] ?? json['grace_period_started_at']),
      alertTriggeredAt: _parseDate(
          json['alertTriggeredAt'] ?? json['alert_triggered_at']),
      nextEvaluationAt: _parseDate(
          json['nextEvaluationAt'] ?? json['next_evaluation_at']),
      scheduleWindows: windows,
      timezone: json['timezone']?.toString() ?? 'Asia/Ho_Chi_Minh',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'relationshipId': relationshipId,
      'currentState': currentState.name,
      'inactivityThresholdMinutes': inactivityThresholdMinutes,
      'checkInGraceMinutes': checkInGraceMinutes,
      'checkInGracePeriodMinutes': checkInGracePeriodMinutes,
      'escalationGracePeriodMinutes': escalationGracePeriodMinutes,
      'locationEnabled': locationEnabled,
      'isPaused': isPaused,
      if (pausedUntil != null) 'pausedUntil': pausedUntil!.toIso8601String(),
      if (lastMeaningfulActivityAt != null)
        'lastMeaningfulActivityAt': lastMeaningfulActivityAt!.toIso8601String(),
      if (checkInRequestedAt != null)
        'checkInRequestedAt': checkInRequestedAt!.toIso8601String(),
      if (gracePeriodStartedAt != null)
        'gracePeriodStartedAt': gracePeriodStartedAt!.toIso8601String(),
      if (alertTriggeredAt != null)
        'alertTriggeredAt': alertTriggeredAt!.toIso8601String(),
      if (nextEvaluationAt != null)
        'nextEvaluationAt': nextEvaluationAt!.toIso8601String(),
      'scheduleWindows': scheduleWindows.map((w) => w.toJson()).toList(),
      'timezone': timezone,
      'enabled': enabled,
    };
  }

  MonitoringConfigModel copyWith({
    String? id,
    String? relationshipId,
    MonitoringState? currentState,
    int? inactivityThresholdMinutes,
    int? checkInGracePeriodMinutes,
    int? escalationGracePeriodMinutes,
    bool? locationEnabled,
    bool? isPaused,
    DateTime? pausedUntil,
    DateTime? lastMeaningfulActivityAt,
    DateTime? checkInRequestedAt,
    DateTime? gracePeriodStartedAt,
    DateTime? alertTriggeredAt,
    DateTime? nextEvaluationAt,
    List<ScheduleWindowModel>? scheduleWindows,
    String? timezone,
    bool? enabled,
  }) {
    return MonitoringConfigModel(
      id: id ?? this.id,
      relationshipId: relationshipId ?? this.relationshipId,
      currentState: currentState ?? this.currentState,
      inactivityThresholdMinutes:
          inactivityThresholdMinutes ?? this.inactivityThresholdMinutes,
      checkInGracePeriodMinutes:
          checkInGracePeriodMinutes ?? this.checkInGracePeriodMinutes,
      escalationGracePeriodMinutes:
          escalationGracePeriodMinutes ?? this.escalationGracePeriodMinutes,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      isPaused: isPaused ?? this.isPaused,
      pausedUntil: pausedUntil ?? this.pausedUntil,
      lastMeaningfulActivityAt:
          lastMeaningfulActivityAt ?? this.lastMeaningfulActivityAt,
      checkInRequestedAt: checkInRequestedAt ?? this.checkInRequestedAt,
      gracePeriodStartedAt: gracePeriodStartedAt ?? this.gracePeriodStartedAt,
      alertTriggeredAt: alertTriggeredAt ?? this.alertTriggeredAt,
      nextEvaluationAt: nextEvaluationAt ?? this.nextEvaluationAt,
      scheduleWindows: scheduleWindows ?? this.scheduleWindows,
      timezone: timezone ?? this.timezone,
      enabled: enabled ?? this.enabled,
    );
  }
}
