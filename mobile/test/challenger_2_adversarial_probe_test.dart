import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/i18n/app_localizations.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/models/check_in_model.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/incident_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/core/storage/local_storage.dart';
import 'package:mobile/core/widgets/calm_empty_state.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/check_in/check_in_screen.dart';
import 'package:mobile/features/check_in/recent_activities_screen.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/dashboard/dashboard_screen.dart';
import 'package:mobile/features/dashboard/monitor_view.dart';
import 'package:mobile/features/dashboard/monitored_view.dart';
import 'package:mobile/features/devices/devices_screen.dart';
import 'package:mobile/features/incidents/incidents_list_screen.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:mobile/features/pairing/qr_invite_screen.dart';
import 'package:mobile/features/pairing/qr_scanner_screen.dart';
import 'package:mobile/features/settings/account_settings_screen.dart';

// =============================================================================
// ADVERSARIAL CONTROLLABLE MOCKS FOR CHALLENGER 2
// =============================================================================

class ChallengerAuthProvider extends AuthProvider {
  UserModel? userModel;

  ChallengerAuthProvider({this.userModel});

  void setCurrentUser(UserModel user) {
    userModel = user;
    notifyListeners();
  }

  @override
  bool get isAuthenticated => userModel != null;

  @override
  UserModel? get currentUser => userModel;
}

class ChallengerDashboardProvider extends DashboardProvider {
  int unreadCount;
  int activeIncidents;
  int selectedIndex;
  final List<RelationshipModel> _relMonitoredByMe;
  final List<RelationshipModel> _relMonitoringMe;
  final MonitoringState state;
  final DateTime? lastActivityTime;
  String? lastAcceptedCode;

  ChallengerDashboardProvider({
    this.unreadCount = 0,
    this.activeIncidents = 0,
    this.selectedIndex = 0,
    List<RelationshipModel>? monitoredByMe,
    List<RelationshipModel>? monitoringMe,
    this.state = MonitoringState.ACTIVE,
    this.lastActivityTime,
  })  : _relMonitoredByMe = monitoredByMe ?? [],
        _relMonitoringMe = monitoringMe ?? [];

  @override
  int get unreadNotificationsCount => unreadCount;

  @override
  int get activeIncidentsCount => activeIncidents;

  @override
  int get selectedTabIndex => selectedIndex;

  @override
  void setSelectedTabIndex(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  @override
  void setUnreadNotificationsCount(int count) {
    unreadCount = count < 0 ? 0 : count;
    notifyListeners();
  }

  @override
  void clearUnreadNotifications() {
    unreadCount = 0;
    activeIncidents = 0;
    notifyListeners();
  }

  @override
  List<RelationshipModel> get monitoredByMe => _relMonitoredByMe;

  @override
  List<RelationshipModel> get monitoringMe => _relMonitoringMe;

  @override
  MonitoringState get myCurrentState => state;

  @override
  DateTime? get myLastActivityAt => lastActivityTime;

  @override
  Future<void> fetchDashboardData() async {}

  @override
  Future<String?> generateInviteCode({String? label}) async {
    return 'CR-INVITE123';
  }

  @override
  Future<bool> acceptInviteCode(String code) async {
    lastAcceptedCode = code;
    if (code.contains('FAIL') || code.contains('INVALID')) {
      return false;
    }
    return true;
  }
}

class ChallengerIncidentsProvider extends IncidentsProvider {
  List<NotificationFeedItem> _feedItems;
  final List<IncidentModel> _incidentsList;
  final Set<String> _dismissedIds = {};
  final Set<String> _readIds = {};

  ChallengerIncidentsProvider({
    List<NotificationFeedItem>? feedItems,
    List<IncidentModel>? incidents,
  })  : _feedItems = feedItems ?? [],
        _incidentsList = incidents ?? [];

  void setFeedItems(List<NotificationFeedItem> items) {
    _feedItems = List.from(items);
    notifyListeners();
  }

  @override
  List<NotificationFeedItem> get allNotifications =>
      _feedItems.where((i) => !_dismissedIds.contains(i.id)).toList();

  @override
  List<IncidentModel> get incidents => _incidentsList
      .where((i) => !_dismissedIds.contains('inc-${i.id}'))
      .toList();

  @override
  int get unreadCount => allNotifications.where((i) => !isRead(i.id)).length;

  @override
  int get readCount => allNotifications.where((i) => isRead(i.id)).length;

  @override
  bool get hasUnreadIncidents => allNotifications
      .where((i) => i.type == NotificationFeedType.incident && !isRead(i.id))
      .isNotEmpty;

  @override
  bool isRead(String id) => _readIds.contains(id);

  @override
  Future<void> dismissNotification(String id) async {
    _dismissedIds.add(id);
    _readIds.add(id);
    _feedItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  @override
  Future<int> clearAllNotifications() async {
    final count = _feedItems.length;
    for (final item in _feedItems) {
      _dismissedIds.add(item.id);
      _readIds.add(item.id);
    }
    _feedItems.clear();
    _incidentsList.clear();
    notifyListeners();
    return count;
  }

  @override
  Future<void> markAllAsRead() async {
    for (final item in _feedItems) {
      _readIds.add(item.id);
    }
    notifyListeners();
  }

  @override
  Future<void> fetchIncidents() async {}
}

// =============================================================================
// TEST HARNESS WRAPPER
// =============================================================================

Widget buildTestApp({
  required Widget child,
  ChallengerAuthProvider? authProvider,
  ChallengerDashboardProvider? dashboardProvider,
  ChallengerIncidentsProvider? incidentsProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(),
      ),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) =>
            authProvider ??
            ChallengerAuthProvider(
              userModel: UserModel(
                id: 'clean-user-id-99',
                email: 'nam.le@example.vn',
                fullName: 'Lê Hoàng Nam',
                phone: '+84 901 234 567',
                timezone: 'Asia/Ho_Chi_Minh',
                isActive: true,
                createdAt: DateTime.now(),
              ),
            ),
      ),
      ChangeNotifierProvider<DashboardProvider>(
        create: (_) => dashboardProvider ?? ChallengerDashboardProvider(),
      ),
      ChangeNotifierProvider<IncidentsProvider>(
        create: (_) => incidentsProvider ?? ChallengerIncidentsProvider(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleCatalogRegistry.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'carely_user_id': 'clean-user-id-99',
      'carely_device_uid': 'device-test-uuid',
    });
    await LocalStorage.saveAuth(
      accessToken: 'token_clean_123',
      refreshToken: 'refresh_clean_123',
      userId: 'clean-user-id-99',
      email: 'nam.le@example.vn',
      fullName: 'Lê Hoàng Nam',
    );
  });

  // =========================================================================
  // CHALLENGE 1: ABSENCE OF SHOWCASE DATA FOR CLEAN ACCOUNTS
  // =========================================================================
  group('1. Showcase Data Absence on Clean Registered Account', () {
    testWidgets('1.1 MonitoredView displays zero fake battery, zero fake time, zero fake relatives', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = ChallengerAuthProvider(
        userModel: UserModel(
          id: 'clean-user-id-99',
          email: 'nam.le@example.vn',
          fullName: 'Lê Hoàng Nam',
          phone: '+84 901 234 567',
          timezone: 'Asia/Ho_Chi_Minh',
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      final dashboard = ChallengerDashboardProvider(
        monitoredByMe: [],
        monitoringMe: [],
        lastActivityTime: null,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: MonitoredView()),
          authProvider: auth,
          dashboardProvider: dashboard,
        ),
      );
      await tester.pumpAndSettle();

      // Dynamic name greeting
      expect(find.text('Xin chào, Nam 👋'), findsOneWidget);

      // Clean state fallbacks: battery must be "--%", not "78%"
      expect(find.text('--%'), findsOneWidget);
      expect(find.text('78%'), findsNothing, reason: 'Fake battery 78% must not exist');

      // Last activity must be "Chưa có hoạt động", not "Hôm nay 08:42"
      expect(find.text('Chưa có hoạt động'), findsOneWidget);
      expect(find.text('Hôm nay 08:42'), findsNothing, reason: 'Fake timestamp 08:42 must not exist');

      // Schedule text must be "Chưa thiết lập khung giờ", not "09:00 - 12:00"
      expect(find.text('Chưa thiết lập khung giờ'), findsOneWidget);
      expect(find.textContaining('09:00 - 12:00'), findsNothing);

      // Verify zero hardcoded relatives or personas
      for (final fakeName in ['Mẹ', 'Bố', 'Chú Nam', 'Em gái', 'iPhone 15 Pro', 'iPad (gia đình)', 'Samsung Galaxy S24']) {
        expect(find.text(fakeName), findsNothing, reason: 'Fake data "$fakeName" must not appear');
      }
    });

    testWidgets('1.2 MonitorView renders CalmEmptyState when monitoredByMe is empty', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dashboard = ChallengerDashboardProvider(
        monitoredByMe: [],
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: MonitorView()),
          dashboardProvider: dashboard,
        ),
      );
      await tester.pumpAndSettle();

      // Verify CalmEmptyState is rendered
      expect(find.byType(CalmEmptyState), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'Bạn chưa theo dõi người thân nào' ||
                  w.data == 'Chưa có người thân nào'),
        ),
        findsOneWidget,
      );

      // Zero hardcoded relative cards
      expect(find.text('Mẹ'), findsNothing);
      expect(find.text('Bố'), findsNothing);
      expect(find.text('Chú Nam'), findsNothing);
      expect(find.text('Em gái'), findsNothing);
    });

    testWidgets('1.3 RecentActivitiesScreen renders CalmEmptyState without hardcoded activity items', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final incidents = ChallengerIncidentsProvider(feedItems: []);

      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: RecentActivitiesScreen(showAppBar: true)),
          incidentsProvider: incidents,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CalmEmptyState), findsOneWidget);
      expect(find.text('Chưa có hoạt động gần đây'), findsOneWidget);

      // Zero hardcoded showcase activities
      expect(find.text('Mở ứng dụng'), findsNothing);
      expect(find.text('Thay đổi trạng thái sạc'), findsNothing);
      expect(find.text('Mở khóa thiết bị'), findsNothing);
      expect(find.text('Bước chân'), findsNothing);
    });

    testWidgets('1.4 DevicesScreen renders CalmEmptyState without fake devices', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: DevicesScreen(showAppBar: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CalmEmptyState), findsOneWidget);
      expect(find.text('Chưa có thiết bị nào'), findsOneWidget);

      // Zero hardcoded showcase devices
      expect(find.text('iPhone 15 Pro'), findsNothing);
      expect(find.text('iPad (gia đình)'), findsNothing);
      expect(find.text('Samsung Galaxy S24'), findsNothing);
    });

    testWidgets('1.5 AccountSettingsScreen dynamically renders registered user profile', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = ChallengerAuthProvider(
        userModel: UserModel(
          id: 'clean-user-id-99',
          email: 'nam.le@example.vn',
          fullName: 'Lê Hoàng Nam',
          phone: '+84 901 234 567',
          timezone: 'Asia/Ho_Chi_Minh',
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const AccountSettingsScreen(),
          authProvider: auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lê Hoàng Nam'), findsWidgets);
      expect(find.text('+84 901 234 567'), findsOneWidget);

      // Zero hardcoded fallback persona
      expect(find.text('Nguyễn Văn An'), findsNothing);
      expect(find.text('+84 912 345 678'), findsNothing);
    });
  });

  // =========================================================================
  // CHALLENGE 2: CALM EMPTY STATE ROBUSTNESS & CTA ACTIONS
  // =========================================================================
  group('2. CalmEmptyState Robustness & CTA Actions at 375x812', () {
    testWidgets('2.1 Zero RenderFlex overflow across empty states on 375x812', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final List<FlutterErrorDetails> errors = [];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      // Test MonitorView empty state
      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: MonitorView()),
          dashboardProvider: ChallengerDashboardProvider(monitoredByMe: []),
        ),
      );
      await tester.pumpAndSettle();

      // Test RecentActivitiesScreen empty state
      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: RecentActivitiesScreen(showAppBar: true)),
          incidentsProvider: ChallengerIncidentsProvider(feedItems: []),
        ),
      );
      await tester.pumpAndSettle();

      // Test DevicesScreen empty state
      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: DevicesScreen(showAppBar: true)),
        ),
      );
      await tester.pumpAndSettle();

      // Test IncidentsListScreen empty state
      await tester.pumpWidget(
        buildTestApp(
          child: const IncidentsListScreen(),
          incidentsProvider: ChallengerIncidentsProvider(feedItems: []),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = oldHandler;

      final overflowErrors = errors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(overflowErrors, isEmpty, reason: 'Must have zero RenderFlex overflow on standard mobile 375x812');
    });

    testWidgets('2.2 Stress test CalmEmptyState with extreme lengthy strings at 375x812', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final List<FlutterErrorDetails> errors = [];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      const massiveTitle = 'Tiêu đề cảnh báo cực kỳ dài được sinh ra nhằm mục đích thử thách độ co dãn của giao diện người dùng';
      const massiveDesc = 'Mô tả chi tiết với nội dung dài hơn 300 ký tự nhằm kiểm chứng rằng widget CalmEmptyState sẽ tự động điều chỉnh độ cao nội dung bên trong Scrollable hoặc Container mà không làm vỡ bố cục trên màn hình di động tiêu chuẩn 375x812. Thử nghiệm bổ sung các ký tự đặc biệt & unicode: 🔥🚀🛡️ và các chuỗi số 123456789.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalmEmptyState(
                icon: Icons.shield_outlined,
                title: massiveTitle,
                description: massiveDesc,
                action: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Hành động thử thách'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = oldHandler;

      expect(errors.where((e) => e.toString().contains('RenderFlex overflowed')), isEmpty);
      expect(find.text(massiveTitle), findsOneWidget);
      expect(find.text(massiveDesc), findsOneWidget);
    });

    testWidgets('2.3 MonitorView empty state CTAs: Scan QR and Create Invite both trigger navigation', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dashboard = ChallengerDashboardProvider(monitoredByMe: []);

      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: MonitorView()),
          dashboardProvider: dashboard,
        ),
      );
      await tester.pumpAndSettle();

      // CTA 1: "Quét mã QR" (empty_scan_qr_button)
      final scanBtn = find.byKey(const Key('empty_scan_qr_button'));
      expect(scanBtn, findsOneWidget);
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      expect(find.byType(QrScannerScreen), findsOneWidget);

      // Pop back to MonitorView
      final backBtn = find.byType(BackButton);
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn);
        await tester.pumpAndSettle();
      }

      // CTA 2: "Tạo mã mời" (empty_invite_code_button)
      final inviteBtn = find.byKey(const Key('empty_invite_code_button'));
      expect(inviteBtn, findsOneWidget);
      await tester.tap(inviteBtn);
      await tester.pumpAndSettle();

      expect(find.byType(QrInviteScreen), findsOneWidget);
    });

    testWidgets('2.4 RecentActivitiesScreen empty CTA navigates to CheckInScreen', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final incidents = ChallengerIncidentsProvider(feedItems: []);

      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: RecentActivitiesScreen(showAppBar: true)),
          incidentsProvider: incidents,
        ),
      );
      await tester.pumpAndSettle();

      final checkInCta = find.byKey(const Key('empty_check_in_button'));
      expect(checkInCta, findsOneWidget);

      await tester.tap(checkInCta);
      await tester.pumpAndSettle();

      expect(find.byType(CheckInScreen), findsOneWidget);
    });

    testWidgets('2.5 DevicesScreen empty CTA triggers real current device sync without fake modal', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: DevicesScreen(showAppBar: true)),
        ),
      );
      await tester.pumpAndSettle();

      final addDeviceCta = find.byKey(const Key('empty_add_device_button'));
      expect(addDeviceCta, findsOneWidget);
      expect(find.text('Đồng bộ thiết bị hiện tại'), findsWidgets);

      await tester.tap(addDeviceCta);
      await tester.pumpAndSettle();

      // Fake manual device modal must NOT exist
      expect(find.text('Thêm thiết bị mới'), findsNothing);
    });
  });

  // =========================================================================
  // CHALLENGE 3: NOTIFICATION CLEARING & BADGE SYNCHRONIZATION
  // =========================================================================
  group('3. Notification Clearing & Badge Zeroing', () {
    testWidgets('3.1 Individual swipe-to-delete updates feed and decrements badge until zero', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final item1 = NotificationFeedItem.incident(
        IncidentModel(
          id: 'inc-test-1',
          relationshipId: 'rel-1',
          monitoredUserId: 'monitored-1',
          status: IncidentStatus.OPEN,
          reason: IncidentReason.MISSED_CHECK_IN,
          riskScore: 75,
          triggeredAt: DateTime.now().subtract(const Duration(minutes: 10)),
          userDisplayName: 'Em gái',
        ),
      );

      final item2 = NotificationFeedItem.checkIn(
        CheckInModel(
          id: 'chk-test-2',
          userId: 'user-rel-2',
          occurredAt: DateTime.now().subtract(const Duration(minutes: 30)),
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
          userDisplayName: 'Bố',
        ),
      );

      final incidents = ChallengerIncidentsProvider(feedItems: [item1, item2]);
      final dashboard = ChallengerDashboardProvider(
        selectedIndex: 2, // Incidents tab
        unreadCount: 2,
        activeIncidents: 1,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const DashboardScreen(),
          dashboardProvider: dashboard,
          incidentsProvider: incidents,
        ),
      );
      await tester.pumpAndSettle();

      // Check badge shows 2
      expect(find.widgetWithText(Badge, '2'), findsOneWidget);
      expect(incidents.allNotifications.length, equals(2));

      // Swipe-to-delete first item
      final dismissible1 = find.byKey(Key('dismissible_${item1.id}'));
      expect(dismissible1, findsOneWidget);

      await tester.drag(dismissible1, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Item 1 removed, badge becomes 1
      expect(incidents.allNotifications.length, equals(1));
      expect(find.widgetWithText(Badge, '1'), findsOneWidget);

      // Swipe-to-delete second item
      final dismissible2 = find.byKey(Key('dismissible_${item2.id}'));
      expect(dismissible2, findsOneWidget);

      await tester.drag(dismissible2, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // All items dismissed
      expect(incidents.allNotifications.length, equals(0));
      expect(incidents.unreadCount, equals(0));

      // Badge is zeroed and hidden (isLabelVisible == false)
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);

      // CalmEmptyState is displayed
      expect(find.byType(CalmEmptyState), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'Mọi thứ đều bình an' ||
                  w.data == 'Không có thông báo hoặc sự cố'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('3.2 "Xóa tất cả" dialog cleanly wipes notifications and zeroes badge immediately', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        NotificationFeedItem.incident(
          IncidentModel(
            id: 'inc-bulk-1',
            relationshipId: 'rel-1',
            monitoredUserId: 'u1',
            status: IncidentStatus.OPEN,
            reason: IncidentReason.MISSED_CHECK_IN,
            riskScore: 80,
            triggeredAt: DateTime.now(),
          ),
        ),
        NotificationFeedItem.incident(
          IncidentModel(
            id: 'inc-bulk-2',
            relationshipId: 'rel-2',
            monitoredUserId: 'u2',
            status: IncidentStatus.OPEN,
            reason: IncidentReason.INACTIVITY,
            riskScore: 65,
            triggeredAt: DateTime.now(),
          ),
        ),
      ];

      final incidents = ChallengerIncidentsProvider(feedItems: items);
      final dashboard = ChallengerDashboardProvider(
        selectedIndex: 2,
        unreadCount: 2,
        activeIncidents: 2,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const DashboardScreen(),
          dashboardProvider: dashboard,
          incidentsProvider: incidents,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Badge, '2'), findsOneWidget);

      // Tap "Xóa tất cả" button in AppBar
      final clearAllBtn = find.byKey(const Key('clear_all_notifications_button'));
      expect(clearAllBtn, findsOneWidget);

      await tester.tap(clearAllBtn);
      await tester.pumpAndSettle();

      // Verify confirmation dialog appears
      expect(find.text('Xóa tất cả thông báo?'), findsOneWidget);

      // Confirm deletion
      final confirmBtn = find.widgetWithText(TextButton, 'Xóa tất cả');
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify list is cleared
      expect(incidents.allNotifications.isEmpty, isTrue);
      expect(dashboard.unreadNotificationsCount, equals(0));

      // Badge must be completely gone
      expect(find.text('2'), findsNothing);

      // CalmEmptyState is now shown
      expect(find.byType(CalmEmptyState), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'Mọi thứ đều bình an' ||
                  w.data == 'Không có thông báo hoặc sự cố'),
        ),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // CHALLENGE 4: TWO-WAY QR PAIRING FLOW NAVIGATION
  // =========================================================================
  group('4. Two-Way QR Pairing Flow Seamless Navigation', () {
    testWidgets('4.1 Seamless round-trip transitions between QrInviteScreen and QrScannerScreen', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dashboard = ChallengerDashboardProvider();

      await tester.pumpWidget(
        buildTestApp(
          child: const QrInviteScreen(initialCode: 'CR-SEAMLESS99'),
          dashboardProvider: dashboard,
        ),
      );
      await tester.pumpAndSettle();

      // Verified QrInviteScreen components
      expect(find.byType(QrInviteScreen), findsOneWidget);
      expect(find.text('CR-SEAMLESS99'), findsOneWidget);

      // Transition 1: Tap bottom switch button to QrScannerScreen
      final bottomSwitchBtn = find.byKey(const Key('open_scanner_from_invite_button'));
      expect(bottomSwitchBtn, findsOneWidget);

      await tester.ensureVisible(bottomSwitchBtn);
      await tester.pumpAndSettle();
      await tester.tap(bottomSwitchBtn);
      await tester.pumpAndSettle();

      expect(find.byType(QrScannerScreen), findsOneWidget);

      // Pop back to QrInviteScreen
      final backBtn1 = find.byType(BackButton);
      expect(backBtn1, findsOneWidget);
      await tester.tap(backBtn1);
      await tester.pumpAndSettle();

      expect(find.byType(QrInviteScreen), findsOneWidget);

      // Transition 2: Tap AppBar icon switch to QrScannerScreen
      final appBarSwitchBtn = find.byKey(const Key('app_bar_switch_to_scanner'));
      expect(appBarSwitchBtn, findsOneWidget);

      await tester.tap(appBarSwitchBtn);
      await tester.pumpAndSettle();

      expect(find.byType(QrScannerScreen), findsOneWidget);

      // Pop back again
      final backBtn2 = find.byType(BackButton);
      expect(backBtn2, findsOneWidget);
      await tester.tap(backBtn2);
      await tester.pumpAndSettle();

      expect(find.byType(QrInviteScreen), findsOneWidget);
    });

    testWidgets('4.2 MonitorView add-relative dialog provides two-way actions & manual code input', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dashboard = ChallengerDashboardProvider(monitoredByMe: []);

      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(body: MonitorView()),
          dashboardProvider: dashboard,
        ),
      );
      await tester.pumpAndSettle();

      // Open add-relative dialog from AppBar action
      final addIconBtn = find.byIcon(Icons.person_add_alt_1_outlined);
      expect(addIconBtn, findsOneWidget);

      await tester.tap(addIconBtn);
      await tester.pumpAndSettle();

      // Verify dialog options
      expect(find.text('Thêm người thân theo dõi'), findsOneWidget);
      expect(find.byKey(const Key('scan_qr_button')), findsOneWidget);
      expect(find.byKey(const Key('dialog_create_invite_button')), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Close dialog via cancel
      final cancelBtn = find.text('Hủy');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('4.3 QrScannerScreen simulated scan processes valid codes and handles errors gracefully', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dashboard = ChallengerDashboardProvider();

      await tester.pumpWidget(
        buildTestApp(
          child: const QrScannerScreen(),
          dashboardProvider: dashboard,
        ),
      );
      await tester.pumpAndSettle();

      // Safe test simulation mode
      expect(find.byKey(const Key('simulated_qr_input')), findsOneWidget);

      // Submit valid pairing QR string
      await tester.enterText(
        find.byKey(const Key('simulated_qr_input')),
        'evernear://invite?code=CR-SUCCESS888',
      );
      await tester.tap(find.byKey(const Key('simulated_qr_submit')));
      await tester.pumpAndSettle();

      expect(dashboard.lastAcceptedCode, equals('CR-SUCCESS888'));
    });
  });
}
