import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/core/models/device_model.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/check_in_model.dart';
import 'package:mobile/core/models/incident_model.dart';

void main() {
  group('Carely Models & Enums Tests', () {
    test('ActivityType enum contains HEARTBEAT with weight 0.0 concept', () {
      expect(ActivityType.HEARTBEAT.name, 'HEARTBEAT');
      expect(ActivityType.CHECK_IN.name, 'CHECK_IN');
      expect(ActivityType.APP_OPEN.name, 'APP_OPEN');
    });

    test('MonitoringState enum contains required states', () {
      expect(MonitoringState.ACTIVE.name, 'ACTIVE');
      expect(MonitoringState.CHECK_IN_REQUIRED.name, 'CHECK_IN_REQUIRED');
      expect(MonitoringState.GRACE_PERIOD.name, 'GRACE_PERIOD');
      expect(MonitoringState.ALERT_TRIGGERED.name, 'ALERT_TRIGGERED');
      expect(MonitoringState.ACKNOWLEDGED.name, 'ACKNOWLEDGED');
      expect(MonitoringState.RESOLVED.name, 'RESOLVED');
      expect(MonitoringState.PAUSED.name, 'PAUSED');
    });

    test('UserModel.fromJson parses correctly with preferredLanguage', () {
      final json = {
        'id': 'user-123',
        'email': 'user@example.com',
        'fullName': 'Nguyễn Văn A',
        'phone': '0901234567',
        'timezone': 'Asia/Ho_Chi_Minh',
        'preferredLanguage': 'ja',
        'isActive': true,
        'createdAt': '2026-10-06T10:00:00.000Z',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'user-123');
      expect(user.email, 'user@example.com');
      expect(user.fullName, 'Nguyễn Văn A');
      expect(user.phone, '0901234567');
      expect(user.timezone, 'Asia/Ho_Chi_Minh');
      expect(user.preferredLanguage, 'ja');
      expect(user.isActive, true);

      final serialized = user.toJson();
      expect(serialized['preferredLanguage'], 'ja');

      final userUpdated = user.copyWith(preferredLanguage: 'de');
      expect(userUpdated.preferredLanguage, 'de');
    });

    test('DeviceModel.fromJson parses correctly', () {
      final json = {
        'id': 'dev-123',
        'userId': 'user-123',
        'platform': 'ANDROID',
        'deviceModel': 'Pixel 8',
        'osVersion': 'Android 14',
        'appVersion': '1.0.0',
        'batteryLevel': 85,
        'isCharging': false,
        'isActive': true,
        'lastHeartbeatAt': '2026-10-06T10:30:00.000Z',
        'createdAt': '2026-10-06T10:00:00.000Z',
      };

      final device = DeviceModel.fromJson(json);
      expect(device.id, 'dev-123');
      expect(device.platform, DevicePlatform.ANDROID);
      expect(device.batteryLevel, 85);
      expect(device.isCharging, false);
      expect(device.lastHeartbeatAt, isNotNull);
    });

    test('RelationshipModel.fromJson parses correctly', () {
      final json = {
        'id': 'rel-123',
        'monitoredUserId': 'user-1',
        'monitorUserId': 'user-2',
        'status': 'ACCEPTED',
        'inviteCode': 'CR-ABC123',
        'label': 'Bố mẹ',
        'createdAt': '2026-10-06T10:00:00.000Z',
      };

      final rel = RelationshipModel.fromJson(json);
      expect(rel.id, 'rel-123');
      expect(rel.status, RelationshipStatus.ACCEPTED);
      expect(rel.inviteCode, 'CR-ABC123');
      expect(rel.label, 'Bố mẹ');
    });

    test('MonitoringConfigModel.fromJson parses correctly', () {
      final json = {
        'id': 'cfg-123',
        'relationshipId': 'rel-123',
        'currentState': 'ACTIVE',
        'inactivityThresholdMinutes': 180,
        'checkInGracePeriodMinutes': 30,
        'escalationGracePeriodMinutes': 30,
        'locationEnabled': true,
        'isPaused': false,
        'lastMeaningfulActivityAt': '2026-10-06T10:15:00.000Z',
      };

      final config = MonitoringConfigModel.fromJson(json);
      expect(config.id, 'cfg-123');
      expect(config.currentState, MonitoringState.ACTIVE);
      expect(config.inactivityThresholdMinutes, 180);
      expect(config.checkInGracePeriodMinutes, 30);
      expect(config.locationEnabled, true);
      expect(config.isPaused, false);
    });

    test('CheckInModel.fromJson parses correctly', () {
      final json = {
        'id': 'chk-123',
        'userId': 'user-123',
        'occurredAt': '2026-10-06T11:00:00.000Z',
        'batteryLevel': 90,
        'note': 'Tôi vẫn ổn',
        'location': {'latitude': 10.762622, 'longitude': 106.660172},
        'createdAt': '2026-10-06T11:00:00.000Z',
      };

      final checkIn = CheckInModel.fromJson(json);
      expect(checkIn.id, 'chk-123');
      expect(checkIn.batteryLevel, 90);
      expect(checkIn.note, 'Tôi vẫn ổn');
      expect(checkIn.latitude, closeTo(10.7626, 0.001));
      expect(checkIn.longitude, closeTo(106.6601, 0.001));
    });

    test('IncidentModel.fromJson parses correctly', () {
      final json = {
        'id': 'inc-123',
        'relationshipId': 'rel-123',
        'monitoredUserId': 'user-123',
        'status': 'TRIGGERED',
        'reason': 'MISSED_CHECK_IN',
        'riskScore': 75,
        'triggeredAt': '2026-10-06T11:30:00.000Z',
      };

      final incident = IncidentModel.fromJson(json);
      expect(incident.id, 'inc-123');
      expect(incident.status, IncidentStatus.TRIGGERED);
      expect(incident.reason, IncidentReason.MISSED_CHECK_IN);
      expect(incident.riskScore, 75);
    });
  });
}
