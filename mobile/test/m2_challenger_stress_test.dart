import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/api_endpoints.dart';
import 'package:mobile/core/constants/app_strings.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/services/permission_service.dart';
import 'package:mobile/core/services/sync_queue_service.dart';
import 'package:mobile/core/widgets/calm_empty_state.dart';
import 'package:mobile/core/widgets/calm_error_card.dart';
import 'package:mobile/core/widgets/calm_loading_widget.dart';
import 'package:mobile/features/check_in/check_in_screen.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // FOCUS AREA 1: Schedule Windows & Boundary Rollovers Stress Tests
  // =========================================================================
  group('1. Schedule Windows & Boundary Rollovers Stress Tests', () {
    test('Boundary times: 00:00 to 23:59 (full intra-day window)', () {
      final window = ScheduleWindowModel(
        dayOfWeek: 1, // Monday
        startTime: '00:00',
        endTime: '23:59',
        isEnabled: true,
      );

      expect(window.isOvernight, false,
          reason: '00:00 -> 23:59 should NOT be classified as overnight');
      expect(window.dayNameShort, 'T2');
      expect(window.dayNameFull, 'Thứ Hai');
      expect(window.nextDayNameFull, 'Thứ Ba');
    });

    test('Boundary times: 23:59 to 00:00 (1-minute midnight rollover)', () {
      final window = ScheduleWindowModel(
        dayOfWeek: 1, // Monday
        startTime: '23:59',
        endTime: '00:00',
        isEnabled: true,
      );

      expect(window.isOvernight, true,
          reason: '23:59 -> 00:00 crosses midnight and is overnight');
      expect(window.dayNameShort, 'T2');
      expect(window.dayNameFull, 'Thứ Hai');
      expect(window.nextDayNameFull, 'Thứ Ba');
    });

    test('Boundary times: 00:00 to 00:00 (zero-duration midnight boundary)', () {
      final window = ScheduleWindowModel(
        dayOfWeek: 2, // Tuesday
        startTime: '00:00',
        endTime: '00:00',
        isEnabled: true,
      );

      expect(window.isOvernight, false,
          reason: '00:00 -> 00:00 is zero duration, not overnight');
    });

    test('Boundary times: 23:59 to 23:59 (zero-duration end-of-day boundary)', () {
      final window = ScheduleWindowModel(
        dayOfWeek: 2, // Tuesday
        startTime: '23:59',
        endTime: '23:59',
        isEnabled: true,
      );

      expect(window.isOvernight, false,
          reason: '23:59 -> 23:59 is zero duration, not overnight');
    });

    test('Overnight span: 22:00 to 06:00 (standard night window)', () {
      final window = ScheduleWindowModel(
        dayOfWeek: 3, // Wednesday
        startTime: '22:00',
        endTime: '06:00',
        isEnabled: true,
      );

      expect(window.isOvernight, true);
      expect(window.dayNameShort, 'T4');
      expect(window.dayNameFull, 'Thứ Tư');
      expect(window.nextDayNameFull, 'Thứ Năm');
    });

    test('Weekend transition: Saturday (6) 23:00 to Sunday (0) 07:00', () {
      final satWindow = ScheduleWindowModel(
        dayOfWeek: 6, // Saturday
        startTime: '23:00',
        endTime: '07:00',
        isEnabled: true,
      );

      expect(satWindow.isOvernight, true);
      expect(satWindow.dayNameShort, 'T7');
      expect(satWindow.dayNameFull, 'Thứ Bảy');
      expect(satWindow.nextDayNameFull, 'Chủ Nhật',
          reason: 'Day following Saturday (6) must wrap to Sunday (0)');
    });

    test('Weekend transition: Sunday (0) 22:00 to Monday (1) 06:00', () {
      final sunWindow = ScheduleWindowModel(
        dayOfWeek: 0, // Sunday
        startTime: '22:00',
        endTime: '06:00',
        isEnabled: true,
      );

      expect(sunWindow.isOvernight, true);
      expect(sunWindow.dayNameShort, 'CN');
      expect(sunWindow.dayNameFull, 'Chủ Nhật');
      expect(sunWindow.nextDayNameFull, 'Thứ Hai',
          reason: 'Day following Sunday (0) must wrap to Monday (1)');
    });

    test('Friday (5) 22:00 to Saturday (6) 06:00 span', () {
      final friWindow = ScheduleWindowModel(
        dayOfWeek: 5, // Friday
        startTime: '22:00',
        endTime: '06:00',
        isEnabled: true,
      );

      expect(friWindow.isOvernight, true);
      expect(friWindow.dayNameShort, 'T6');
      expect(friWindow.dayNameFull, 'Thứ Sáu');
      expect(friWindow.nextDayNameFull, 'Thứ Bảy');
    });

    test('Validate complete 7-day name mapping and nextDay rollover', () {
      final expectedShort = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      final expectedFull = [
        'Chủ Nhật',
        'Thứ Hai',
        'Thứ Ba',
        'Thứ Tư',
        'Thứ Năm',
        'Thứ Sáu',
        'Thứ Bảy',
      ];
      final expectedNextFull = [
        'Thứ Hai',
        'Thứ Ba',
        'Thứ Tư',
        'Thứ Năm',
        'Thứ Sáu',
        'Thứ Bảy',
        'Chủ Nhật',
      ];

      for (int d = 0; d <= 6; d++) {
        final w = ScheduleWindowModel(
          dayOfWeek: d,
          startTime: '20:00',
          endTime: '08:00',
        );
        expect(w.dayNameShort, expectedShort[d]);
        expect(w.dayNameFull, expectedFull[d]);
        expect(w.nextDayNameFull, expectedNextFull[d]);
      }
    });

    test('Validate Dart DateTime.weekday vs Backend TypeORM day_of_week mapping', () {
      // Dart DateTime: Monday=1 ... Saturday=6, Sunday=7
      // Backend TypeORM / JS Date: Sunday=0, Monday=1 ... Saturday=6
      // Invariant: backendDayOfWeek = dartWeekday % 7

      final testDates = [
        DateTime(2026, 10, 5), // Monday
        DateTime(2026, 10, 6), // Tuesday
        DateTime(2026, 10, 7), // Wednesday
        DateTime(2026, 10, 8), // Thursday
        DateTime(2026, 10, 9), // Friday
        DateTime(2026, 10, 10), // Saturday
        DateTime(2026, 10, 11), // Sunday
      ];

      final expectedBackendDays = [1, 2, 3, 4, 5, 6, 0];

      for (int i = 0; i < testDates.length; i++) {
        final date = testDates[i];
        final dartWeekday = date.weekday;
        final backendDay = dartWeekday % 7;

        expect(backendDay, expectedBackendDays[i],
            reason:
                'Dart weekday $dartWeekday must map to backend day ${expectedBackendDays[i]} via `% 7`');

        final model = ScheduleWindowModel(
          dayOfWeek: backendDay,
          startTime: '08:00',
          endTime: '18:00',
        );

        if (dartWeekday == DateTime.sunday) {
          expect(model.dayOfWeek, 0);
          expect(model.dayNameShort, 'CN');
          expect(model.dayNameFull, 'Chủ Nhật');
        } else {
          expect(model.dayOfWeek, dartWeekday);
          expect(model.dayNameShort, 'T${dartWeekday + 1}');
        }
      }
    });

    test('JSON deserialization handles both snake_case and camelCase payloads', () {
      final snakeJson = {
        'id': 'win-snake',
        'config_id': 'cfg-snake',
        'day_of_week': 0,
        'start_time': '21:00',
        'end_time': '05:00',
        'is_enabled': true,
      };

      final camelJson = {
        'id': 'win-camel',
        'configId': 'cfg-camel',
        'dayOfWeek': 6,
        'startTime': '08:00',
        'endTime': '17:00',
        'isEnabled': false,
      };

      final snakeModel = ScheduleWindowModel.fromJson(snakeJson);
      expect(snakeModel.id, 'win-snake');
      expect(snakeModel.configId, 'cfg-snake');
      expect(snakeModel.dayOfWeek, 0);
      expect(snakeModel.startTime, '21:00');
      expect(snakeModel.endTime, '05:00');
      expect(snakeModel.isEnabled, true);
      expect(snakeModel.isOvernight, true);

      final camelModel = ScheduleWindowModel.fromJson(camelJson);
      expect(camelModel.id, 'win-camel');
      expect(camelModel.configId, 'cfg-camel');
      expect(camelModel.dayOfWeek, 6);
      expect(camelModel.startTime, '08:00');
      expect(camelModel.endTime, '17:00');
      expect(camelModel.isEnabled, false);
      expect(camelModel.isOvernight, false);
    });

    test('Out-of-range dayOfWeek behavior (boundary stress)', () {
      // If dayOfWeek is 7 (unconverted Dart Sunday), normalized via % 7
      final invalidSundayModel = ScheduleWindowModel(
        dayOfWeek: 7,
        startTime: '08:00',
        endTime: '17:00',
      );
      // With dayOfWeek normalized via `% 7`, passing 7 is safely normalized to 0 (Sunday / 'CN'),
      // preventing confusing Sunday with Saturday ('T7').
      expect(invalidSundayModel.dayOfWeek, 0);
      expect(invalidSundayModel.dayNameShort, 'CN');
      expect(invalidSundayModel.nextDayNameFull, 'Thứ Hai');
    });
  });

  // =========================================================================
  // FOCUS AREA 2: Permission Service Graceful Degradation Stress
  // =========================================================================
  group('2. Permission Service Graceful Degradation Stress Tests', () {
    const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
    const geolocatorAndroidChannel =
        MethodChannel('flutter.baseflow.com/geolocator_android');
    const permissionChannel =
        MethodChannel('flutter.baseflow.com/permissions/methods');

    void registerGeolocatorHandler(Future<dynamic>? Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geolocatorChannel, handler);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geolocatorAndroidChannel, handler);
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geolocatorChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geolocatorAndroidChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, null);
    });

    test('Unmocked / missing plugin calls degrade gracefully to null / false without crash',
        () async {
      final service = PermissionService();

      // In unit test without native platform channels, these must not throw
      final notifResult = await service.requestNotificationPermission();
      expect(notifResult, isFalse);

      final locationResult = await service.getSingleShotLocation();
      expect(locationResult, isNull);
    });

    test('Degrades gracefully when GPS / Location Service is disabled on device',
        () async {
      registerGeolocatorHandler((MethodCall call) async {
        if (call.method == 'isLocationServiceEnabled') {
          return false; // GPS disabled
        }
        return null;
      });

      final service = PermissionService();
      final loc = await service.getSingleShotLocation();
      expect(loc, isNull, reason: 'Disabled location service must return null cleanly');
    });

    test('Degrades gracefully when Location Permission is denied', () async {
      registerGeolocatorHandler((MethodCall call) async {
        if (call.method == 'isLocationServiceEnabled') {
          return true;
        }
        if (call.method == 'checkPermission') {
          return 0; // LocationPermission.denied
        }
        if (call.method == 'requestPermission') {
          return 0; // denied again by user
        }
        return null;
      });

      final service = PermissionService();
      final loc = await service.getSingleShotLocation();
      expect(loc, isNull, reason: 'Denied permission must return null cleanly');
    });

    test('Degrades gracefully when Location Permission is permanently denied',
        () async {
      registerGeolocatorHandler((MethodCall call) async {
        if (call.method == 'isLocationServiceEnabled') {
          return true;
        }
        if (call.method == 'checkPermission') {
          return 1; // LocationPermission.deniedForever
        }
        return null;
      });

      final service = PermissionService();
      final loc = await service.getSingleShotLocation();
      expect(loc, isNull, reason: 'Permanently denied permission must return null cleanly');
    });

    test('Degrades gracefully when GPS location lookup times out', () async {
      registerGeolocatorHandler((MethodCall call) async {
        if (call.method == 'isLocationServiceEnabled') return true;
        if (call.method == 'checkPermission') return 2; // whileInUse
        if (call.method == 'getCurrentPosition') {
          throw PlatformException(
            code: 'LOCATION_TIMEOUT',
            message: 'Location request timed out after 5 seconds',
          );
        }
        return null;
      });

      final service = PermissionService();
      final loc = await service.getSingleShotLocation();
      expect(loc, isNull, reason: 'Timeout must return null cleanly without throwing');
    });

    test('Degrades gracefully when Notification Permission is denied or permanently denied',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
        if (call.method == 'checkPermissionStatus') {
          return 0; // PermissionStatus.denied
        }
        if (call.method == 'requestPermissions') {
          return {
            17: 4 // Permission.notification (17) -> permanentlyDenied (4)
          };
        }
        return null;
      });

      final service = PermissionService();
      final granted = await service.requestNotificationPermission();
      expect(granted, isFalse, reason: 'Denied notification must return false cleanly');
    });

    test('Check-in flow succeeds and omits location field when GPS returns null (Online)',
        () async {
      SharedPreferences.setMockInitialValues({
        'carely_user_id': 'user-monitored-1',
        'carely_device_uid': 'device-test-uuid',
      });

      final apiClient = ApiClient();
      Map<String, dynamic>? capturedPayload;

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == ApiEndpoints.checkIns) {
            capturedPayload = options.data as Map<String, dynamic>;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {'success': true, 'id': 'chk-123'},
              ),
            );
          }
          if (options.path == ApiEndpoints.relationships) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'monitoring': [], 'monitoredBy': []},
              ),
            );
          }
          if (options.path == ApiEndpoints.incidents) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: [],
              ),
            );
          }
          return handler.next(options);
        },
      );

      apiClient.dio.interceptors.insert(0, interceptor);

      try {
        final provider = DashboardProvider();

        // sendCheckIn with GPS returning null (unmocked)
        final success = await provider.sendCheckIn(
          note: 'Trực tuyến không có GPS',
          batteryLevel: 90,
        );

        expect(success, isTrue);
        expect(provider.lastCheckInOffline, isFalse);
        expect(capturedPayload, isNotNull);
        expect(capturedPayload!['deviceId'], 'device-test-uuid');
        expect(capturedPayload!['note'], 'Trực tuyến không có GPS');
        expect(capturedPayload!['batteryLevel'], 90);
        expect(capturedPayload!.containsKey('location'), isFalse,
            reason: 'Payload must omit location field cleanly when GPS is null');
      } finally {
        apiClient.dio.interceptors.remove(interceptor);
      }
    });

    test('Check-in flow enqueues offline when network fails and omits location field',
        () async {
      SharedPreferences.setMockInitialValues({
        'carely_user_id': 'user-monitored-1',
        'carely_device_uid': 'device-test-uuid',
      });

      final apiClient = ApiClient();
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == ApiEndpoints.checkIns) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: const SocketException('Network offline'),
              ),
            );
          }
          return handler.next(options);
        },
      );

      apiClient.dio.interceptors.insert(0, interceptor);

      try {
        final queueService = SyncQueueService();
        await queueService.clearQueue();

        final provider = DashboardProvider();
        final success = await provider.sendCheckIn(
          note: 'Ngoại tuyến không có GPS',
          batteryLevel: 75,
        );

        expect(success, isTrue,
            reason: 'Check-in must succeed via offline fallback queue');
        expect(provider.lastCheckInOffline, isTrue);

        final queueLength = await queueService.getQueueLength();
        expect(queueLength, 1);

        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('carely_offline_sync_queue')!;
        final List list = jsonDecode(raw) as List;
        final item = list.first as Map<String, dynamic>;
        expect(item['type'], 'checkIn');
        final payload = item['payload'] as Map<String, dynamic>;
        expect(payload['deviceId'], 'device-test-uuid');
        expect(payload['note'], 'Ngoại tuyến không có GPS');
        expect(payload['batteryLevel'], 75);
        expect(payload.containsKey('location'), isFalse,
            reason: 'Queued payload must cleanly omit location when GPS is null');
      } finally {
        apiClient.dio.interceptors.remove(interceptor);
      }
    });
  });

  // =========================================================================
  // FOCUS AREA 3: Calm UX Copywriting Completeness & Widget Error State Tests
  // =========================================================================
  group('3. Calm UX Copywriting Completeness & Widget Resilience', () {
    test('AppStrings contains non-alarmist, reassuring Vietnamese strings', () {
      expect(AppStrings.checkInButton, 'Tôi vẫn ổn');
      expect(AppStrings.checkInPrompt,
          'Bạn vẫn ổn chứ? Vui lòng chạm để xác nhận.');
      expect(AppStrings.checkInSuccess,
          'Đã gửi xác nhận bình an thành công.');
      expect(AppStrings.checkInOfflineSuccess, contains('bộ nhớ máy'));
      expect(AppStrings.stateActive, 'Tình trạng ổn định');
      expect(AppStrings.stateCheckInRequired, 'Cần kiểm tra an tâm');
      expect(AppStrings.stateGracePeriod, 'Chờ phản hồi');
      expect(AppStrings.stateAlertTriggered, 'Đã liên hệ người thân');
      expect(AppStrings.stateAcknowledged, 'Người thân đã tiếp nhận');
      expect(AppStrings.stateResolved, 'Đã hoàn tất hỗ trợ');
      expect(AppStrings.statePaused, 'Đang tạm dừng giám sát');
      expect(AppStrings.calmEmptyIncidentsTitle, 'Mọi thứ đều bình an');
      expect(AppStrings.retryButton, 'Thử lại');
    });

    testWidgets('CalmErrorCard renders calm warm-amber styling and retry button',
        (tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalmErrorCard(
              title: 'Chưa thể kết nối',
              message: 'Vui lòng kiểm tra đường truyền mạng.',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Chưa thể kết nối'), findsOneWidget);
      expect(find.text('Vui lòng kiểm tra đường truyền mạng.'), findsOneWidget);
      expect(find.text(AppStrings.retryButton), findsOneWidget);

      await tester.tap(find.text(AppStrings.retryButton));
      await tester.pump();

      expect(retryPressed, isTrue,
          reason: 'Retry callback must be triggered on tap');
    });

    testWidgets('CalmEmptyState renders reassuring title and description',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CalmEmptyState(
              title: AppStrings.calmEmptyIncidentsTitle,
              description: AppStrings.calmEmptyIncidentsDesc,
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.calmEmptyIncidentsTitle), findsOneWidget);
      expect(find.text(AppStrings.calmEmptyIncidentsDesc), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
    });

    testWidgets('CalmLoadingWidget renders comforting progress message',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CalmLoadingWidget(
              message: 'Đang kết nối trạng thái an tâm...',
            ),
          ),
        ),
      );

      expect(find.text('Đang kết nối trạng thái an tâm...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('CheckInScreen renders calm UI and handles 1-touch check-in',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'carely_user_id': 'user-elderly-1',
        'carely_device_uid': 'device-elderly-phone',
      });

      final apiClient = ApiClient();
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == ApiEndpoints.checkIns) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {'success': true},
              ),
            );
          }
          if (options.path == ApiEndpoints.relationships) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'monitoring': [], 'monitoredBy': []},
              ),
            );
          }
          if (options.path == ApiEndpoints.incidents) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: [],
              ),
            );
          }
          return handler.next(options);
        },
      );

      apiClient.dio.interceptors.insert(0, interceptor);

      try {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ],
            child: const MaterialApp(
              home: CheckInScreen(),
            ),
          ),
        );

        expect(find.text(AppStrings.checkInPrompt), findsOneWidget);
        expect(find.text(AppStrings.checkInButton), findsOneWidget);
        expect(find.text('Xác nhận an toàn'), findsOneWidget);

        // Verify privacy / calm reminder
        expect(
          find.textContaining('Bạn không cần mở app liên tục'),
          findsOneWidget,
        );

        // Tap "Tôi vẫn ổn"
        await tester.tap(find.text(AppStrings.checkInButton));
        await tester.pump(); // Start async action
        await tester.pump(const Duration(milliseconds: 500)); // Complete async action

        // App should not crash
        expect(tester.takeException(), isNull,
            reason: 'Check-in tap must never throw unhandled exceptions');
      } finally {
        apiClient.dio.interceptors.remove(interceptor);
      }
    });
  });
}
