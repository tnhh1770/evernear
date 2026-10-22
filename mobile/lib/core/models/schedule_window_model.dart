import '../i18n/app_localizations.dart';

class ScheduleWindowModel {
  final String? id;
  final String? configId;
  final int dayOfWeek; // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
  final String startTime; // HH:mm format, e.g. "07:00"
  final String endTime; // HH:mm format, e.g. "22:00"
  final bool isEnabled;

  ScheduleWindowModel({
    this.id,
    this.configId,
    required int dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isEnabled = true,
  }) : dayOfWeek = (dayOfWeek % 7);

  /// Converts Dart DateTime.weekday (1..7, Monday..Sunday) to backend/Evernear dayOfWeek (0..6, Sunday..Saturday).
  static int fromDartWeekday(int weekday) => weekday % 7;

  /// Converts a Dart DateTime instance to backend/Evernear dayOfWeek (0..6).
  static int fromDateTime(DateTime dt) => dt.weekday % 7;

  /// Converts backend/Evernear dayOfWeek (0..6) back to Dart DateTime.weekday (1..7, where 0/Sunday becomes DateTime.sunday = 7).
  int toDartWeekday() => dayOfWeek == 0 ? DateTime.sunday : dayOfWeek;

  factory ScheduleWindowModel.fromJson(Map<String, dynamic> json) {
    final rawDay = json['dayOfWeek'] ?? json['day_of_week'];
    final parsedDay = (rawDay is num ? rawDay.toInt() : int.tryParse('$rawDay')) ?? 0;

    return ScheduleWindowModel(
      id: json['id']?.toString(),
      configId: json['configId']?.toString() ?? json['config_id']?.toString(),
      dayOfWeek: parsedDay % 7,
      startTime: json['startTime']?.toString() ?? json['start_time']?.toString() ?? '07:00',
      endTime: json['endTime']?.toString() ?? json['end_time']?.toString() ?? '22:00',
      isEnabled: json['isEnabled'] as bool? ?? json['is_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (configId != null) 'configId': configId,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'isEnabled': isEnabled,
    };
  }

  ScheduleWindowModel copyWith({
    String? id,
    String? configId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    bool? isEnabled,
  }) {
    return ScheduleWindowModel(
      id: id ?? this.id,
      configId: configId ?? this.configId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// Convenience getters for Sleep / Quiet Hours UI framing
  String get wakeTime => startTime;
  String get bedtime => endTime;

  /// Overnight window auto-detection (e.g. 22:00 -> 06:00)
  bool get isOvernight {
    return startTime.compareTo(endTime) > 0;
  }

  static String shortDayKeyFor(int day) {
    switch (day) {
      case 1:
        return 'day_name_short_mon';
      case 2:
        return 'day_name_short_tue';
      case 3:
        return 'day_name_short_wed';
      case 4:
        return 'day_name_short_thu';
      case 5:
        return 'day_name_short_fri';
      case 6:
        return 'day_name_short_sat';
      case 0:
        return 'day_name_short_sun';
      default:
        return 'day_name_short_mon';
    }
  }

  static String _defaultShortDayName(int day) {
    switch (day) {
      case 1:
        return 'T2';
      case 2:
        return 'T3';
      case 3:
        return 'T4';
      case 4:
        return 'T5';
      case 5:
        return 'T6';
      case 6:
        return 'T7';
      case 0:
        return 'CN';
      default:
        return 'T$day';
    }
  }

  /// Localized short day name (e.g. 'T2'..'CN' for vi, 'Mon'..'Sun' for en)
  String get dayNameShort {
    return AppLocalizations.staticTr(
      shortDayKeyFor(dayOfWeek),
      fallback: _defaultShortDayName(dayOfWeek),
    );
  }

  /// Explicitly localized short day name
  String dayNameShortLocalized([String? languageCode]) {
    return AppLocalizations.staticTr(
      shortDayKeyFor(dayOfWeek),
      fallback: _defaultShortDayName(dayOfWeek),
    );
  }

  static String dayKeyFor(int day) {
    switch (day) {
      case 1:
        return 'day_monday';
      case 2:
        return 'day_tuesday';
      case 3:
        return 'day_wednesday';
      case 4:
        return 'day_thursday';
      case 5:
        return 'day_friday';
      case 6:
        return 'day_saturday';
      case 0:
        return 'day_sunday';
      default:
        return 'day_monday';
    }
  }

  static String _defaultDayName(int day) {
    return AppLocalizations.staticTr(dayKeyFor(day));
  }

  /// Localized full day name
  String get dayNameFull {
    return AppLocalizations.staticTr(dayKeyFor(dayOfWeek), fallback: _defaultDayName(dayOfWeek));
  }

  /// Full name of the next day (for overnight display)
  String get nextDayNameFull {
    final nextDay = (dayOfWeek + 1) % 7;
    return AppLocalizations.staticTr(dayKeyFor(nextDay), fallback: _defaultDayName(nextDay));
  }
}
