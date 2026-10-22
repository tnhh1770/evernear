import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/i18n/locale_catalog_registry.dart';
import 'package:mobile/core/i18n/locale_provider.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/incident_model.dart';
import 'package:mobile/core/models/monitoring_config_model.dart';
import 'package:mobile/core/models/relationship_model.dart';
import 'package:mobile/core/models/schedule_window_model.dart';
import 'package:mobile/core/models/user_model.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/dashboard/dashboard_screen.dart';
import 'package:mobile/features/dashboard/monitored_view.dart';
import 'package:mobile/features/incidents/incidents_list_screen.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:mobile/features/settings/language_settings_screen.dart';

class MockDashboardProvider extends DashboardProvider {
  int _fakeActiveIncidentsCount = 0;
  bool _fakeIsLoading = false;
  List<RelationshipModel> _fakeRelationships = [];

  MockDashboardProvider({List<RelationshipModel>? relationships}) {
    _fakeRelationships = relationships ?? [];
  }

  @override
  int get activeIncidentsCount => _fakeActiveIncidentsCount;

  @override
  bool get isLoading => _fakeIsLoading;

  @override
  List<RelationshipModel> get allRelationships => _fakeRelationships;

  @override
  List<RelationshipModel> get monitoredByMe => _fakeRelationships;

  @override
  List<RelationshipModel> get monitoringMe => _fakeRelationships;

  @override
  MonitoringState get myCurrentState => MonitoringState.ACTIVE;

  @override
  DateTime? get myLastActivityAt => DateTime(2026, 10, 12, 10, 0);

  @override
  Future<void> fetchDashboardData() async {
    // no-op for tests
  }

  void updateLoading(bool loading) {
    _fakeIsLoading = loading;
    notifyListeners();
  }

  void updateIncidentsCount(int count) {
    _fakeActiveIncidentsCount = count;
    notifyListeners();
  }

  void updateRelationships(List<RelationshipModel> rels) {
    _fakeRelationships = rels;
    notifyListeners();
  }
}

class MockIncidentsProvider extends IncidentsProvider {
  List<IncidentModel> _mockIncidents = [];
  bool _mockIsLoading = false;

  MockIncidentsProvider({List<IncidentModel>? incidents, bool isLoading = false}) {
    _mockIncidents = incidents ?? [];
    _mockIsLoading = isLoading;
  }

  @override
  List<IncidentModel> get incidents => _mockIncidents;

  @override
  bool get isLoading => _mockIsLoading;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchIncidents() async {
    // no-op
  }
}

RelationshipModel createMockRelationship(String id) {
  return RelationshipModel(
    id: id,
    monitoredUserId: 'user-monitored-$id',
    monitorUserId: 'user-monitor-$id',
    status: RelationshipStatus.ACCEPTED,
    createdAt: DateTime.now(),
    monitorUser: UserModel(
      id: 'user-monitor-$id',
      email: 'guardian$id@carely.vn',
      fullName: 'Người thân $id',
      timezone: 'Asia/Ho_Chi_Minh',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    config: MonitoringConfigModel(
      id: 'cfg-$id',
      relationshipId: id,
      currentState: MonitoringState.ACTIVE,
      inactivityThresholdMinutes: 180,
      checkInGracePeriodMinutes: 30,
      escalationGracePeriodMinutes: 30,
      locationEnabled: true,
      isPaused: false,
      timezone: 'Asia/Ho_Chi_Minh',
      scheduleWindows: [
        ScheduleWindowModel(
          dayOfWeek: 1,
          startTime: '07:00',
          endTime: '22:00',
          isEnabled: true,
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'carely_user_id': 'user-monitored-1',
    });
  });

  group('Opt-M3 Challenger: UI Rendering & Rebuild Performance Stress Suite', () {
    testWidgets('1. Selector rebuild scoping in DashboardScreen: Non-badge mutations do NOT rebuild Scaffold/body', (tester) async {
      final mockDashboard = MockDashboardProvider();
      final mockIncidents = MockIncidentsProvider();
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DashboardProvider>.value(value: mockDashboard),
            ChangeNotifierProvider<IncidentsProvider>.value(value: mockIncidents),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      final dashboardFinder = find.byType(DashboardScreen);
      final scaffoldFinder = find.byType(Scaffold);
      final indexedStackFinder = find.byType(IndexedStack);

      expect(dashboardFinder, findsOneWidget);
      expect(scaffoldFinder, findsOneWidget);
      expect(indexedStackFinder, findsOneWidget);

      final dashboardElement = tester.element(dashboardFinder);
      final scaffoldElement = tester.element(scaffoldFinder);
      final indexedStackElement = tester.element(indexedStackFinder);

      expect(dashboardElement.dirty, isFalse);
      expect(scaffoldElement.dirty, isFalse);
      expect(indexedStackElement.dirty, isFalse);

      // Mutate 1: Change isLoading
      mockDashboard.updateLoading(true);

      expect(dashboardElement.dirty, isFalse, reason: 'Mutating isLoading must not mark DashboardScreen dirty');
      expect(scaffoldElement.dirty, isFalse, reason: 'Mutating isLoading must not mark Scaffold dirty');
      expect(indexedStackElement.dirty, isFalse, reason: 'Mutating isLoading must not mark IndexedStack dirty');

      await tester.pump();
      mockDashboard.updateLoading(false);
      expect(dashboardElement.dirty, isFalse);
      expect(scaffoldElement.dirty, isFalse);
      expect(indexedStackElement.dirty, isFalse);
      await tester.pump();

      // Mutate 2: Change relationships list
      mockDashboard.updateRelationships([
        createMockRelationship('rel-1'),
        createMockRelationship('rel-2'),
      ]);

      expect(dashboardElement.dirty, isFalse, reason: 'Mutating relationships must not mark DashboardScreen dirty');
      expect(scaffoldElement.dirty, isFalse);
      expect(indexedStackElement.dirty, isFalse);
      await tester.pump();

      // Mutate 3: Change activeIncidentsCount from 0 to 4
      mockDashboard.updateIncidentsCount(4);

      expect(dashboardElement.dirty, isFalse, reason: 'DashboardScreen itself must NOT rebuild when incident count changes');
      expect(scaffoldElement.dirty, isFalse, reason: 'Scaffold must NOT rebuild when incident count changes');
      expect(indexedStackElement.dirty, isFalse, reason: 'IndexedStack must NOT rebuild when incident count changes');

      await tester.pump();
      expect(find.text('4'), findsAtLeastNWidgets(1), reason: 'Badge should display 4');

      // Mutate 4: Change activeIncidentsCount back to 0
      mockDashboard.updateIncidentsCount(0);
      expect(dashboardElement.dirty, isFalse);
      expect(scaffoldElement.dirty, isFalse);
      expect(indexedStackElement.dirty, isFalse);
      await tester.pump();

      expect(find.text('4'), findsNothing, reason: 'Badge label should disappear when count is 0');
    });

    testWidgets('2. IndexedStack preserves scroll position and widget state across tab switches', (tester) async {
      // Provide multiple relationships so MonitoredView has sufficient scrollable height
      final mockDashboard = MockDashboardProvider(relationships: [
        createMockRelationship('rel-1'),
        createMockRelationship('rel-2'),
        createMockRelationship('rel-3'),
        createMockRelationship('rel-4'),
        createMockRelationship('rel-5'),
      ]);
      final mockIncidents = MockIncidentsProvider();
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DashboardProvider>.value(value: mockDashboard),
            ChangeNotifierProvider<IncidentsProvider>.value(value: mockIncidents),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      final monitoredViewFinder = find.byType(MonitoredView);
      expect(monitoredViewFinder, findsOneWidget);

      final scrollableFinder = find.descendant(
        of: monitoredViewFinder,
        matching: find.byType(Scrollable),
      );
      expect(scrollableFinder, findsOneWidget);

      final ScrollableState initialScrollable = tester.state(scrollableFinder);
      expect(initialScrollable.position.pixels, 0.0);
      expect(initialScrollable.position.maxScrollExtent, greaterThan(100.0),
          reason: 'MonitoredView with 5 relatives must be scrollable');

      // Scroll down by 250px
      await tester.drag(scrollableFinder, const Offset(0, -250));
      await tester.pump();

      final double scrolledOffset = initialScrollable.position.pixels;
      expect(scrolledOffset, greaterThan(150.0), reason: 'Scroll offset should be advanced');

      // Switch to Tab 1: Theo dõi (MonitorView)
      await tester.tap(find.text('Theo dõi'));
      await tester.pump();

      final IndexedStack indexedStack1 = tester.widget(find.byType(IndexedStack));
      expect(indexedStack1.index, equals(1));

      // MonitoredView is retained in element tree (via IndexedStack maintainState: true)
      expect(find.byType(MonitoredView, skipOffstage: false), findsOneWidget);
      expect(initialScrollable.position.pixels, equals(scrolledOffset));

      // Switch to Tab 3: Cài đặt (SettingsScreen)
      await tester.tap(find.text('Cài đặt'));
      await tester.pump();

      final IndexedStack indexedStack3 = tester.widget(find.byType(IndexedStack));
      expect(indexedStack3.index, equals(3));
      expect(initialScrollable.position.pixels, equals(scrolledOffset));

      // Switch to Tab 2: Thông báo (IncidentsListScreen / NotificationsScreen)
      final tab2Finder = find.text('Thông báo').evaluate().isNotEmpty
          ? find.text('Thông báo')
          : find.text('Sự cố');
      await tester.tap(tab2Finder);
      await tester.pump();

      final IndexedStack indexedStack2 = tester.widget(find.byType(IndexedStack));
      expect(indexedStack2.index, equals(2));
      expect(initialScrollable.position.pixels, equals(scrolledOffset));

      // Switch BACK to Tab 0: Trạng thái (MonitoredView)
      await tester.tap(find.text('Trạng thái'));
      await tester.pump();

      final IndexedStack indexedStack0 = tester.widget(find.byType(IndexedStack));
      expect(indexedStack0.index, equals(0));

      // Scroll position must be preserved exactly
      expect(initialScrollable.position.pixels, equals(scrolledOffset),
          reason: 'IndexedStack must retain MonitoredView scroll position upon returning to Tab 0');

      // Rapid tab switching stress: 16 iterations
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Theo dõi'));
        await tester.pump();
        await tester.tap(tab2Finder);
        await tester.pump();
        await tester.tap(find.text('Cài đặt'));
        await tester.pump();
        await tester.tap(find.text('Trạng thái'));
        await tester.pump();
        expect(initialScrollable.position.pixels, equals(scrolledOffset));
      }
    });

    testWidgets('3. RepaintBoundary on MonitoredView pulse button isolates paint invalidations', (tester) async {
      final mockDashboard = MockDashboardProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<DashboardProvider>.value(
          value: mockDashboard,
          child: const MaterialApp(
            home: Scaffold(
              body: MonitoredView(),
            ),
          ),
        ),
      );
      await tester.pump();

      final pulseBoundaryFinder = find.descendant(
        of: find.byType(Center),
        matching: find.byType(RepaintBoundary),
      );
      expect(pulseBoundaryFinder, findsAtLeastNWidgets(1));

      final RenderObject renderObject = tester.renderObject(pulseBoundaryFinder.first);
      expect(renderObject, isA<RenderRepaintBoundary>());

      final RenderRepaintBoundary boundary = renderObject as RenderRepaintBoundary;
      expect(boundary.isRepaintBoundary, isTrue, reason: 'Pulse halo must be an independent repaint boundary');

      // Pump frames across animation timeline
      for (int t = 0; t < 10; t++) {
        await tester.pump(const Duration(milliseconds: 220));
      }

      expect(boundary.isRepaintBoundary, isTrue);
    });

    testWidgets('4. Lazy virtualization in IncidentsListScreen: CustomScrollView + SliverList.builder culls offscreen items', (tester) async {
      // Generate 120 incident items
      final incidents = List.generate(
        120,
        (i) => IncidentModel(
          id: 'inc-item-$i',
          relationshipId: 'rel-test',
          monitoredUserId: 'user-monitored-1',
          status: i % 2 == 0 ? IncidentStatus.OPEN : IncidentStatus.RESOLVED,
          reason: IncidentReason.MISSED_CHECK_IN,
          riskScore: 50 + (i % 50),
          triggeredAt: DateTime(2026, 10, 12, 10, 0).subtract(Duration(hours: i)),
        ),
      );

      final mockIncidents = MockIncidentsProvider(incidents: incidents);

      await tester.pumpWidget(
        ChangeNotifierProvider<IncidentsProvider>.value(
          value: mockIncidents,
          child: const MaterialApp(
            home: IncidentsListScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify CustomScrollView and SliverList exist
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SliverList), findsOneWidget);

      // In default 800x600 viewport, out of 120 items, only a small subset is instantiated
      final renderedCards = find.byType(Card).evaluate().length;
      expect(renderedCards, lessThan(15), reason: 'SliverList must NOT eagerly lay out 120 items; expected < 15 cards rendered');
      expect(renderedCards, greaterThan(2), reason: 'Viewport should render visible cards');

      // Item 119 should NOT be in the element tree
      expect(find.text('inc-item-119'), findsNothing);

      // Scroll down by 2000px
      final scrollableFinder = find.byType(Scrollable);
      await tester.drag(scrollableFinder, const Offset(0, -2000));
      await tester.pump();

      // After large scroll, items should still be bounded and elements recycled
      final scrolledRenderedCards = find.byType(Card).evaluate().length;
      expect(scrolledRenderedCards, lessThan(20), reason: 'Virtualization must maintain a bounded window of element widgets');
    });

    testWidgets('5. Lazy virtualization in LanguageSettingsScreen: 50+ languages are not eagerly laid out', (tester) async {
      final localeProvider = LocaleProvider();
      await localeProvider.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      // Total catalog languages is >= 50
      expect(LocaleCatalogRegistry.allLanguages.length, greaterThanOrEqualTo(50));

      // Verify CustomScrollView with lazy sliver lists
      expect(find.byType(CustomScrollView), findsOneWidget);
      // Initially, only the visible sliver(s) are built in the viewport
      expect(find.byType(SliverList), findsAtLeastNWidgets(1));

      // Total rendered ListTile widgets in 800x600 viewport must be strictly bounded
      final initialTiles = find.byType(ListTile).evaluate().length;
      expect(initialTiles, lessThan(15),
          reason: 'Language catalog with 50+ entries must NOT eagerly lay out all items; found $initialTiles tiles');

      // Scroll down by 1500px to reach Section 3 (All Languages)
      final scrollableFinder = find.byType(CustomScrollView);
      await tester.drag(scrollableFinder, const Offset(0, -1500));
      await tester.pump();

      // After scrolling into Section 3, second sliver is materialized and tiles remain bounded
      expect(find.byType(SliverList), findsAtLeastNWidgets(1));
      final scrolledTiles = find.byType(ListTile).evaluate().length;
      expect(scrolledTiles, lessThan(18),
          reason: 'After scroll, virtualization should continue maintaining bounded active tiles; found $scrolledTiles');
    });
  });
}
