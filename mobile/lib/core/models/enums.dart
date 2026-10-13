enum ActivityType {
  // Canonical Backend values
  APP_OPEN,
  APP_FOREGROUND,
  CHECK_IN,
  DEVICE_MOTION,
  STEP_DETECTED,
  CHARGER_CONNECTED,
  CHARGER_DISCONNECTED,
  SCREEN_INTERACTION,
  LOCATION_UPDATE,
  HEARTBEAT,

  // Legacy / UI aliases
  SCREEN_UNLOCK,
  CHARGING_STARTED,
  CHARGING_STOPPED,
  SIGNIFICANT_MOTION,
  STEP_BATCH,
  GEOFENCE_TRANSITION,
  NOTIFICATION_ENGAGED,
  MANUAL_SELF_REPORT;

  static ActivityType fromString(String? value) {
    if (value == null) return ActivityType.APP_OPEN;
    switch (value.toUpperCase()) {
      case 'APP_OPEN':
        return ActivityType.APP_OPEN;
      case 'APP_FOREGROUND':
        return ActivityType.APP_FOREGROUND;
      case 'CHECK_IN':
        return ActivityType.CHECK_IN;
      case 'DEVICE_MOTION':
      case 'SIGNIFICANT_MOTION':
        return ActivityType.DEVICE_MOTION;
      case 'STEP_DETECTED':
      case 'STEP_BATCH':
        return ActivityType.STEP_DETECTED;
      case 'CHARGER_CONNECTED':
      case 'CHARGING_STARTED':
        return ActivityType.CHARGER_CONNECTED;
      case 'CHARGER_DISCONNECTED':
      case 'CHARGING_STOPPED':
        return ActivityType.CHARGER_DISCONNECTED;
      case 'SCREEN_INTERACTION':
      case 'SCREEN_UNLOCK':
        return ActivityType.SCREEN_INTERACTION;
      case 'LOCATION_UPDATE':
      case 'GEOFENCE_TRANSITION':
        return ActivityType.LOCATION_UPDATE;
      case 'HEARTBEAT':
        return ActivityType.HEARTBEAT;
      case 'NOTIFICATION_ENGAGED':
        return ActivityType.NOTIFICATION_ENGAGED;
      case 'MANUAL_SELF_REPORT':
        return ActivityType.MANUAL_SELF_REPORT;
      default:
        return ActivityType.APP_OPEN;
    }
  }

  String toBackendString() {
    switch (this) {
      case ActivityType.CHARGING_STARTED:
      case ActivityType.CHARGER_CONNECTED:
        return 'CHARGER_CONNECTED';
      case ActivityType.CHARGING_STOPPED:
      case ActivityType.CHARGER_DISCONNECTED:
        return 'CHARGER_DISCONNECTED';
      case ActivityType.SIGNIFICANT_MOTION:
      case ActivityType.DEVICE_MOTION:
        return 'DEVICE_MOTION';
      case ActivityType.STEP_BATCH:
      case ActivityType.STEP_DETECTED:
        return 'STEP_DETECTED';
      case ActivityType.SCREEN_UNLOCK:
      case ActivityType.SCREEN_INTERACTION:
        return 'SCREEN_INTERACTION';
      case ActivityType.GEOFENCE_TRANSITION:
      case ActivityType.LOCATION_UPDATE:
        return 'LOCATION_UPDATE';
      default:
        return name;
    }
  }
}

enum MonitoringState {
  // Canonical Backend values
  INACTIVE_MONITORING,
  ACTIVE,
  CHECK_IN_REQUIRED,
  CHECK_IN_PENDING,
  WARNING,
  ESCALATED,
  ACKNOWLEDGED,
  RESOLVED,
  SUSPENDED,

  // Legacy / UI aliases
  INITIALIZING,
  GRACE_PERIOD,
  ALERT_TRIGGERED,
  PAUSED;

  static MonitoringState fromString(String? value) {
    if (value == null) return MonitoringState.ACTIVE;
    switch (value.toUpperCase()) {
      case 'INACTIVE_MONITORING':
      case 'INITIALIZING':
        return MonitoringState.INACTIVE_MONITORING;
      case 'ACTIVE':
        return MonitoringState.ACTIVE;
      case 'CHECK_IN_REQUIRED':
        return MonitoringState.CHECK_IN_REQUIRED;
      case 'CHECK_IN_PENDING':
      case 'GRACE_PERIOD':
        return MonitoringState.CHECK_IN_PENDING;
      case 'WARNING':
        return MonitoringState.WARNING;
      case 'ESCALATED':
      case 'ALERT_TRIGGERED':
        return MonitoringState.ESCALATED;
      case 'ACKNOWLEDGED':
        return MonitoringState.ACKNOWLEDGED;
      case 'RESOLVED':
        return MonitoringState.RESOLVED;
      case 'SUSPENDED':
      case 'PAUSED':
        return MonitoringState.SUSPENDED;
      default:
        return MonitoringState.ACTIVE;
    }
  }

  bool get isPaused => this == MonitoringState.SUSPENDED || this == MonitoringState.PAUSED;
  bool get isWarningOrAlert =>
      this == MonitoringState.WARNING ||
      this == MonitoringState.ESCALATED ||
      this == MonitoringState.ALERT_TRIGGERED;
}

enum RelationshipStatus {
  // Canonical Backend values
  PENDING,
  ACCEPTED,
  REJECTED,
  SUSPENDED,

  // Legacy / UI alias
  REVOKED;

  static RelationshipStatus fromString(String? value) {
    if (value == null) return RelationshipStatus.PENDING;
    switch (value.toUpperCase()) {
      case 'PENDING':
        return RelationshipStatus.PENDING;
      case 'ACCEPTED':
        return RelationshipStatus.ACCEPTED;
      case 'REJECTED':
        return RelationshipStatus.REJECTED;
      case 'SUSPENDED':
      case 'REVOKED':
        return RelationshipStatus.SUSPENDED;
      default:
        return RelationshipStatus.PENDING;
    }
  }
}

enum IncidentStatus {
  // Canonical Backend values
  OPEN,
  ESCALATED,
  ACKNOWLEDGED,
  RESOLVED,
  CANCELLED,

  // Legacy / UI aliases
  TRIGGERED,
  FALSE_ALARM;

  static IncidentStatus fromString(String? value) {
    if (value == null) return IncidentStatus.OPEN;
    switch (value.toUpperCase()) {
      case 'OPEN':
        return IncidentStatus.OPEN;
      case 'TRIGGERED':
        return IncidentStatus.TRIGGERED;
      case 'ESCALATED':
        return IncidentStatus.ESCALATED;
      case 'ACKNOWLEDGED':
        return IncidentStatus.ACKNOWLEDGED;
      case 'RESOLVED':
        return IncidentStatus.RESOLVED;
      case 'CANCELLED':
        return IncidentStatus.CANCELLED;
      case 'FALSE_ALARM':
        return IncidentStatus.FALSE_ALARM;
      default:
        return IncidentStatus.OPEN;
    }
  }

  bool get isOpen =>
      this == IncidentStatus.OPEN ||
      this == IncidentStatus.TRIGGERED ||
      this == IncidentStatus.ESCALATED;

  bool get isResolved =>
      this == IncidentStatus.RESOLVED ||
      this == IncidentStatus.ACKNOWLEDGED ||
      this == IncidentStatus.CANCELLED ||
      this == IncidentStatus.FALSE_ALARM;
}

enum IncidentReason {
  // Canonical Backend values
  INACTIVITY,
  MISSED_CHECK_IN,
  DEVICE_OFFLINE,
  MANUAL_SOS,

  // Legacy / UI aliases
  EXTENDED_INACTIVITY,
  MANUAL_TRIGGER,
  CRITICAL_BATTERY_INACTIVITY;

  static IncidentReason fromString(String? value) {
    if (value == null) return IncidentReason.INACTIVITY;
    switch (value.toUpperCase()) {
      case 'INACTIVITY':
        return IncidentReason.INACTIVITY;
      case 'EXTENDED_INACTIVITY':
        return IncidentReason.EXTENDED_INACTIVITY;
      case 'MISSED_CHECK_IN':
        return IncidentReason.MISSED_CHECK_IN;
      case 'DEVICE_OFFLINE':
        return IncidentReason.DEVICE_OFFLINE;
      case 'CRITICAL_BATTERY_INACTIVITY':
        return IncidentReason.CRITICAL_BATTERY_INACTIVITY;
      case 'MANUAL_SOS':
        return IncidentReason.MANUAL_SOS;
      case 'MANUAL_TRIGGER':
        return IncidentReason.MANUAL_TRIGGER;
      default:
        return IncidentReason.INACTIVITY;
    }
  }
}

enum DevicePlatform {
  ANDROID,
  IOS,
  WEB;

  static DevicePlatform fromString(String? value) {
    if (value == null) return DevicePlatform.ANDROID;
    switch (value.toUpperCase()) {
      case 'ANDROID':
        return DevicePlatform.ANDROID;
      case 'IOS':
        return DevicePlatform.IOS;
      case 'WEB':
        return DevicePlatform.WEB;
      default:
        return DevicePlatform.ANDROID;
    }
  }
}
