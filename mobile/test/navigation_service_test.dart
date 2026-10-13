import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/navigation_service.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/incidents/incident_detail_screen.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationService Unit & Widget Tests', () {
    test('1. Initial navigatorKey exists and has correct type', () {
      expect(NavigationService.navigatorKey, isA<GlobalKey<NavigatorState>>());
    });

    test('2. handleNotificationPayload gracefully returns false for empty or unhandled payload', () async {
      final handled = await NavigationService.handleNotificationPayload({});
      expect(handled, isFalse);
    });

    testWidgets('3. handleNotificationPayload navigates to IncidentDetailScreen when incidentId is present', (tester) async {
      final incidentsProvider = IncidentsProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<IncidentsProvider>.value(
          value: incidentsProvider,
          child: MaterialApp(
            navigatorKey: NavigationService.navigatorKey,
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );

      final handled = await NavigationService.handleNotificationPayload({
        'incidentId': 'inc_test_456',
        'type': 'INCIDENT_CREATED',
      });

      expect(handled, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(IncidentDetailScreen), findsOneWidget);
    });

    testWidgets('4. handleNotificationPayload switches to notifications tab when type is CHECK_IN_CONFIRMED', (tester) async {
      final dashboardProvider = DashboardProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<DashboardProvider>.value(
          value: dashboardProvider,
          child: MaterialApp(
            navigatorKey: NavigationService.navigatorKey,
            home: const Scaffold(body: Text('Dashboard')),
          ),
        ),
      );

      expect(dashboardProvider.selectedTabIndex, 0);

      final handled = await NavigationService.handleNotificationPayload({
        'type': 'CHECK_IN_CONFIRMED',
        'userId': 'user_xyz',
      });

      expect(handled, isTrue);
      expect(dashboardProvider.selectedTabIndex, 2);
    });
  });
}
