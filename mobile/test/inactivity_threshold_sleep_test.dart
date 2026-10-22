import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/dashboard/monitored_view.dart';
import 'package:mobile/features/monitoring/monitoring_settings_screen.dart';
import 'package:provider/provider.dart';

class FakeDashboardProvider extends DashboardProvider {
  final List<RelationshipModel> _mockMonitoringMe;

  FakeDashboardProvider({List<RelationshipModel>? monitoringMe})
      : _mockMonitoringMe = monitoringMe ?? [];

  @override
  List<RelationshipModel> get monitoringMe => _mockMonitoringMe;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  MonitoringState get myCurrentState => MonitoringState.ACTIVE;

  @override
  DateTime? get myLastActivityAt => DateTime(2026, 10, 8, 10, 30);
}

RelationshipModel createTestRelationship({int inactivityThresholdMinutes = 180}) {
  return RelationshipModel(
    id: 'rel-test-123',
    monitoredUserId: 'user-monitored-1',
    monitorUserId: 'user-monitor-2',
    status: RelationshipStatus.ACCEPTED,
    createdAt: DateTime.now(),
    config: MonitoringConfigModel(
      id: 'cfg-test-123',
      relationshipId: 'rel-test-123',
      currentState: MonitoringState.ACTIVE,
      inactivityThresholdMinutes: inactivityThresholdMinutes,
      checkInGracePeriodMinutes: 30,
      escalationGracePeriodMinutes: 30,
      locationEnabled: true,
      isPaused: false,
      timezone: 'Asia/Ho_Chi_Minh',
      scheduleWindows: [
        ScheduleWindowModel(
          dayOfWeek: 1, // Monday
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
        ),
      ],
    ),
    monitoredUser: UserModel(
      id: 'user-monitored-1',
      email: 'elder@carely.test',
      fullName: 'Bà Nguyễn Thị Ba',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    monitorUser: UserModel(
      id: 'user-monitor-2',
      email: 'guardian@carely.test',
      fullName: 'Anh Nguyễn Văn Hai',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      createdAt: DateTime.now(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Feature 45 & 46: ScheduleWindowModel Convenience Getters', () {
    test('wakeTime and bedtime return startTime and endTime', () {
      final window = ScheduleWindowModel(
        dayOfWeek: 1,
        startTime: '07:15',
        endTime: '22:45',
      );
      expect(window.wakeTime, equals('07:15'));
      expect(window.bedtime, equals('22:45'));
    });

    test('overnight windows detect bedtime > wakeTime correctly', () {
      final nightWindow = ScheduleWindowModel(
        dayOfWeek: 2,
        startTime: '21:00',
        endTime: '05:30',
      );
      expect(nightWindow.wakeTime, equals('21:00'));
      expect(nightWindow.bedtime, equals('05:30'));
      expect(nightWindow.isOvernight, isTrue);
    });
  });

  group('Feature 45: Inactivity Threshold Preset Chips & Custom Input', () {
    testWidgets('Renders all standard preset chips: 15p, 30p, 1h, 2h, 4h, 8h, 12h, 24h', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationship(inactivityThresholdMinutes: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('15p'), findsOneWidget);
      expect(find.text('30p'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      expect(find.text('4h'), findsOneWidget);
      expect(find.text('8h'), findsOneWidget);
      expect(find.text('12h'), findsOneWidget);
      expect(find.text('24h'), findsOneWidget);
      expect(find.text('Tùy biến...'), findsOneWidget);

      // 1h chip should be selected initially
      final chip1h = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('1h'), matching: find.byType(ChoiceChip)),
      );
      expect(chip1h.selected, isTrue);
    });

    testWidgets('Tapping preset chip updates selected threshold and preview text', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationship(inactivityThresholdMinutes: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 30p chip
      await tester.tap(find.text('30p'));
      await tester.pumpAndSettle();

      final chip30p = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('30p'), matching: find.byType(ChoiceChip)),
      );
      expect(chip30p.selected, isTrue);
      expect(find.text('30 phút'), findsOneWidget);

      // Tap 24h chip
      await tester.tap(find.text('24h'));
      await tester.pumpAndSettle();

      final chip24h = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('24h'), matching: find.byType(ChoiceChip)),
      );
      expect(chip24h.selected, isTrue);
      expect(find.text('1440 phút (24 giờ)'), findsOneWidget);
    });

    testWidgets('Non-standard backend threshold renders safely without crashing (assertion-safe)', (tester) async {
      setLargeViewport(tester);
      // Threshold 45 min is not in standard presets [15, 30, 60, 120, 240, 480, 720, 1440]
      final rel = createTestRelationship(inactivityThresholdMinutes: 45);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Should automatically select custom chip labeled 'Tùy biến (45p)'
      expect(find.text('Tùy biến (45p)'), findsOneWidget);
      final customChip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('Tùy biến (45p)'), matching: find.byType(ChoiceChip)),
      );
      expect(customChip.selected, isTrue);

      // Check preview text
      expect(find.text('45 phút'), findsOneWidget);
    });

    testWidgets('Non-standard 90 min threshold renders safely with hour-minute preview', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationship(inactivityThresholdMinutes: 90);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tùy biến (90p)'), findsOneWidget);
      expect(find.text('90 phút (1 giờ 30 phút)'), findsOneWidget);
    });

    testWidgets('Custom threshold dialog validates and applies new numeric value', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationship(inactivityThresholdMinutes: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Tùy biến...' chip
      await tester.tap(find.text('Tùy biến...'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Tùy biến thời gian'), findsOneWidget);
      expect(find.text('Áp dụng'), findsOneWidget);

      // Enter out-of-bounds value 0 minutes
      final textField = find.byType(TextField);
      await tester.enterText(textField, '0');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      // Validation error shown, dialog still open
      expect(find.text('Số phút phải từ 1 đến 1440 (24 giờ)'), findsOneWidget);
      expect(find.text('Tùy biến thời gian'), findsOneWidget);

      // Enter valid custom minutes 90
      await tester.enterText(textField, '90');
      await tester.pumpAndSettle();

      // Preview inside dialog shows formatted duration
      expect(find.text('Xem trước: 90 phút (1 giờ 30 phút)'), findsOneWidget);

      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      // Dialog dismissed, new threshold 90 applied to screen
      expect(find.text('Tùy biến thời gian'), findsNothing);
      expect(find.text('Tùy biến (90p)'), findsOneWidget);
      expect(find.text('90 phút (1 giờ 30 phút)'), findsOneWidget);
    });
  });

  group('Feature 46: Sleep & Quiet Hours Framing UI', () {
    testWidgets('Renders quiet hours explanation card and bedtime & wake time pickers', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationship(inactivityThresholdMinutes: 180);

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      // Quiet Hours explanation card
      expect(find.textContaining('Khung giờ ngủ / nghỉ ngơi (Quiet Hours)'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Tự động tạm hoãn đánh giá khi bạn ngủ'), findsOneWidget);
      expect(find.textContaining('Cảm biến sạc pin qua đêm vẫn được tiếp nhận an toàn'), findsOneWidget);

      // Bedtime & Wake time framing
      expect(find.text('Giờ thức dậy (Bắt đầu giám sát)'), findsOneWidget);
      expect(find.text('Giờ đi ngủ (Bắt đầu giờ nghỉ)'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);

      // Summary calculation badge: 07:00 to 22:00 = 15h active, 22:00 to 07:00 = 9h sleep
      expect(find.textContaining('Thời gian ngủ: 9 giờ'), findsOneWidget);
      expect(find.textContaining('Giám sát an tâm: 15 giờ'), findsOneWidget);
    });

    testWidgets('Day selector strip switches active day and displays short day names', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationship();

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('T2'), findsOneWidget);
      expect(find.text('T3'), findsOneWidget);
      expect(find.text('T4'), findsOneWidget);
      expect(find.text('T5'), findsOneWidget);
      expect(find.text('T6'), findsOneWidget);
      expect(find.text('T7'), findsOneWidget);
      expect(find.text('CN'), findsOneWidget);

      // Tap T3
      await tester.tap(find.text('T3'));
      await tester.pumpAndSettle();

      expect(find.text('Thứ Ba'), findsOneWidget);
    });

    testWidgets('Apply to all days button shows confirmation SnackBar', (tester) async {
      setLargeViewport(tester);
      final rel = createTestRelationship();

      await tester.pumpWidget(
        MaterialApp(
          home: MonitoringSettingsScreen(relationship: rel),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Áp dụng cho cả tuần'));
      await tester.pumpAndSettle();

      expect(find.text('Đã áp dụng khung giờ này cho toàn bộ các ngày trong tuần.'), findsOneWidget);
    });
  });

  group('Feature 45 & 46: MonitoredView Navigation Entry Points', () {
    testWidgets('MonitoredView renders sleep settings button and navigates to MonitoringSettingsScreen', (tester) async {
      setLargeViewport(tester);
      final testRel = createTestRelationship();
      final fakeProvider = FakeDashboardProvider(monitoringMe: [testRel]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DashboardProvider>.value(
            value: fakeProvider,
            child: const Scaffold(body: MonitoredView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display settings navigation button
      expect(find.text('Cài đặt Khung giờ ngủ & Giám sát'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      // Tap settings button
      await tester.tap(find.text('Cài đặt Khung giờ ngủ & Giám sát'));
      await tester.pumpAndSettle();

      // Navigated to MonitoringSettingsScreen
      expect(find.byType(MonitoringSettingsScreen), findsOneWidget);
      expect(find.textContaining('Khung giờ ngủ / nghỉ ngơi (Quiet Hours)'), findsAtLeastNWidgets(1));
    });

    testWidgets('Tapping relative card in MonitoredView navigates to MonitoringSettingsScreen', (tester) async {
      setLargeViewport(tester);
      final testRel = createTestRelationship();
      final fakeProvider = FakeDashboardProvider(monitoringMe: [testRel]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DashboardProvider>.value(
            value: fakeProvider,
            child: const Scaffold(body: MonitoredView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap relative card ListTile
      await tester.tap(find.text('Anh Nguyễn Văn Hai'));
      await tester.pumpAndSettle();

      // Navigated to MonitoringSettingsScreen
      expect(find.byType(MonitoringSettingsScreen), findsOneWidget);
    });

    testWidgets('Tapping tune icon in relative card navigates to MonitoringSettingsScreen', (tester) async {
      setLargeViewport(tester);
      final testRel = createTestRelationship();
      final fakeProvider = FakeDashboardProvider(monitoringMe: [testRel]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DashboardProvider>.value(
            value: fakeProvider,
            child: const Scaffold(body: MonitoredView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap tune icon button
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      // Navigated to MonitoringSettingsScreen
      expect(find.byType(MonitoringSettingsScreen), findsOneWidget);
    });
  });
}
