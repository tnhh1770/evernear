import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/device_model.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/user_model.dart';

void main() {
  group('Milestone 3 Challenger: Mobile Model Serialization & Deserialization Stress Tests', () {
    group('UserModel.fromJson Robustness & Edge Cases', () {
      test('1.1 Empty Map: UserModel handles {} without crashing', () {
        final user = UserModel.fromJson({});
        expect(user.id, '');
        expect(user.email, '');
        expect(user.fullName, '');
        expect(user.phone, isNull);
        expect(user.timezone, 'Asia/Ho_Chi_Minh');
        expect(user.isActive, isTrue);
        expect(user.createdAt, isNotNull);
      });

      test('1.2 All Null Fields: handles explicit nulls without TypeError', () {
        final user = UserModel.fromJson({
          'id': null,
          'email': null,
          'fullName': null,
          'phone': null,
          'timezone': null,
          'isActive': null,
          'createdAt': null,
        });
        expect(user.id, '');
        expect(user.email, '');
        expect(user.fullName, '');
        expect(user.phone, isNull);
        expect(user.timezone, 'Asia/Ho_Chi_Minh');
        expect(user.isActive, isTrue);
        expect(user.createdAt, isNotNull);
      });

      test('1.3 Name Aliases Cascading: fullName, full_name, displayName, display_name, name', () {
        expect(UserModel.fromJson({'fullName': 'Name 1'}).fullName, 'Name 1');
        expect(UserModel.fromJson({'full_name': 'Name 2'}).fullName, 'Name 2');
        expect(UserModel.fromJson({'displayName': 'Name 3'}).fullName, 'Name 3');
        expect(UserModel.fromJson({'display_name': 'Name 4'}).fullName, 'Name 4');
        expect(UserModel.fromJson({'name': 'Name 5'}).fullName, 'Name 5');
        // Priority order
        expect(
          UserModel.fromJson({
            'fullName': 'Primary',
            'full_name': 'Secondary',
            'displayName': 'Tertiary',
          }).fullName,
          'Primary',
        );
      });

      test('1.4 Phone Aliases Cascading: phone, phoneNumber, phone_number', () {
        expect(UserModel.fromJson({'phone': '+84901'}).phone, '+84901');
        expect(UserModel.fromJson({'phoneNumber': '+84902'}).phone, '+84902');
        expect(UserModel.fromJson({'phone_number': '+84903'}).phone, '+84903');
      });

      test('1.5 Non-string / Numeric IDs: id converted via toString()', () {
        final user = UserModel.fromJson({'id': 98765});
        expect(user.id, '98765');
      });

      test('1.6 Varied Timestamp representations for createdAt', () {
        // ISO string
        final u1 = UserModel.fromJson({'createdAt': '2026-10-07T12:00:00.000Z'});
        expect(u1.createdAt.toUtc().year, 2026);

        // Integer epoch millis
        final u2 = UserModel.fromJson({'createdAt': 1760000000000});
        expect(u2.createdAt.millisecondsSinceEpoch, 1760000000000);

        // String numeric epoch millis
        final u3 = UserModel.fromJson({'createdAt': '1760000000000'});
        expect(u3.createdAt.millisecondsSinceEpoch, 1760000000000);

        // Double epoch millis
        final u4 = UserModel.fromJson({'createdAt': 1760000000000.0});
        expect(u4.createdAt.millisecondsSinceEpoch, 1760000000000);

        // Invalid string returns fallback DateTime.now() without throwing
        expect(() => UserModel.fromJson({'createdAt': 'not-a-date'}), returnsNormally);
      });

      test('1.7 Active Status Variations', () {
        expect(UserModel.fromJson({'isActive': false}).isActive, isFalse);
        expect(UserModel.fromJson({'is_active': false}).isActive, isFalse);
        expect(UserModel.fromJson({'isActive': true}).isActive, isTrue);
        expect(UserModel.fromJson({}).isActive, isTrue);
      });

      test('1.8 toJson serialization round-trip', () {
        final original = UserModel(
          id: 'u-101',
          email: 'test@carely.vn',
          fullName: 'Trần Văn Bình',
          phone: '+84911223344',
          timezone: 'Asia/Ho_Chi_Minh',
          isActive: true,
          createdAt: DateTime.utc(2026, 10, 7, 8, 30),
        );
        final json = original.toJson();
        final reconstituted = UserModel.fromJson(json);

        expect(reconstituted.id, original.id);
        expect(reconstituted.email, original.email);
        expect(reconstituted.fullName, original.fullName);
        expect(reconstituted.phone, original.phone);
        expect(reconstituted.timezone, original.timezone);
        expect(reconstituted.isActive, original.isActive);
        expect(reconstituted.createdAt.toIso8601String(), original.createdAt.toIso8601String());
      });
    });

    group('DeviceModel.fromJson Robustness & Edge Cases', () {
      test('2.1 Standard payload parsing', () {
        final dev = DeviceModel.fromJson({
          'id': 'dev-1',
          'userId': 'usr-1',
          'platform': 'ANDROID',
          'deviceModel': 'Pixel 8',
          'osVersion': 'Android 14',
          'appVersion': '1.0.0',
          'fcmToken': 'fcm-xyz',
          'batteryLevel': 85,
          'isCharging': false,
          'isActive': true,
          'lastHeartbeatAt': '2026-10-07T10:00:00Z',
          'createdAt': '2026-10-07T09:00:00Z',
        });
        expect(dev.id, 'dev-1');
        expect(dev.userId, 'usr-1');
        expect(dev.platform, DevicePlatform.ANDROID);
        expect(dev.deviceModel, 'Pixel 8');
        expect(dev.fcmToken, 'fcm-xyz');
        expect(dev.batteryLevel, 85);
        expect(dev.isCharging, isFalse);
        expect(dev.isActive, isTrue);
      });

      test('2.2 Field Aliases Cascading (user_id, device_model, os_version, app_version, is_charging, is_active)', () {
        final dev = DeviceModel.fromJson({
          'id': 'dev-2',
          'user_id': 'usr-snake',
          'platform': 'ios',
          'device_model': 'iPhone 15 Pro',
          'os_version': 'iOS 17.5',
          'app_version': '2.1.0',
          'is_charging': true,
          'is_active': false,
          'battery_level': 42,
        });
        expect(dev.userId, 'usr-snake');
        expect(dev.platform, DevicePlatform.IOS);
        expect(dev.deviceModel, 'iPhone 15 Pro');
        expect(dev.osVersion, 'iOS 17.5');
        expect(dev.appVersion, '2.1.0');
        expect(dev.isCharging, isTrue);
        expect(dev.isActive, isFalse);
        expect(dev.batteryLevel, 42);
      });

      test('2.3 Push Token Aliases Cascading: pushToken, push_token, fcmToken, fcm_token', () {
        expect(DeviceModel.fromJson({'id': 'd', 'pushToken': 'pt1'}).fcmToken, 'pt1');
        expect(DeviceModel.fromJson({'id': 'd', 'push_token': 'pt2'}).fcmToken, 'pt2');
        expect(DeviceModel.fromJson({'id': 'd', 'fcmToken': 'pt3'}).fcmToken, 'pt3');
        expect(DeviceModel.fromJson({'id': 'd', 'fcm_token': 'pt4'}).fcmToken, 'pt4');
      });

      test('2.4 Platform Enum case insensitivity & unknown fallback', () {
        expect(DeviceModel.fromJson({'id': 'd', 'platform': 'android'}).platform, DevicePlatform.ANDROID);
        expect(DeviceModel.fromJson({'id': 'd', 'platform': 'IOS'}).platform, DevicePlatform.IOS);
        expect(DeviceModel.fromJson({'id': 'd', 'platform': 'web'}).platform, DevicePlatform.WEB);
        expect(DeviceModel.fromJson({'id': 'd', 'platform': 'windows'}).platform, DevicePlatform.ANDROID);
        expect(DeviceModel.fromJson({'id': 'd', 'platform': null}).platform, DevicePlatform.ANDROID);
      });

      test('2.5 lastHeartbeatAt aliases: lastHeartbeatAt and last_heartbeat_at', () {
        final d1 = DeviceModel.fromJson({'id': 'd', 'lastHeartbeatAt': '2026-10-07T10:00:00Z'});
        expect(d1.lastHeartbeatAt, isNotNull);

        final d2 = DeviceModel.fromJson({'id': 'd', 'last_heartbeat_at': '2026-10-07T10:00:00Z'});
        expect(d2.lastHeartbeatAt, isNotNull);

        final d3 = DeviceModel.fromJson({'id': 'd', 'lastHeartbeatAt': null, 'last_heartbeat_at': null});
        expect(d3.lastHeartbeatAt, isNull);
      });

      test('2.6 CHALLENGE / EDGE CASE: Empty ID or null ID handling', () {
        // Empirically observe how DeviceModel handles empty or null ID
        expect(() => DeviceModel.fromJson({'id': null}), throwsA(isA<TypeError>()));
        expect(() => DeviceModel.fromJson({}), throwsA(isA<TypeError>()));
        expect(() => DeviceModel.fromJson({'id': 123}), throwsA(isA<TypeError>()));
      });

      test('2.7 CHALLENGE / EDGE CASE: Non-integer batteryLevel (e.g. double from SQLite/API)', () {
        // In Dart, `85.0 as int?` throws TypeError
        expect(() => DeviceModel.fromJson({'id': 'd', 'batteryLevel': 85.0}), throwsA(isA<TypeError>()));
      });
    });
  });
}

