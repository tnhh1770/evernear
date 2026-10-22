import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_strings.dart';
import 'package:mobile/core/models/enums.dart';
import 'package:mobile/core/models/incident_model.dart';
import 'package:mobile/core/storage/local_storage.dart';
import 'package:mobile/features/dashboard/dashboard_provider.dart';
import 'package:mobile/features/incidents/incident_detail_screen.dart';
import 'package:mobile/features/incidents/incidents_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IncidentDetailScreen RBAC Tests', () {
    late IncidentModel testIncident;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      testIncident = IncidentModel(
        id: 'inc-rbac-1',
        relationshipId: 'rel-rbac-1',
        monitoredUserId: 'user-monitored-123',
        status: IncidentStatus.OPEN,
        reason: IncidentReason.MISSED_CHECK_IN,
        riskScore: 100,
        triggeredAt: DateTime.now(),
      );
    });

    testWidgets('1. Monitored user viewing own incident does NOT see acknowledge or resolve buttons', (tester) async {
      await LocalStorage.saveAuth(
        accessToken: 'mock_token',
        refreshToken: 'mock_refresh',
        userId: 'user-monitored-123',
        email: 'monitored@test.com',
        fullName: 'Bố Mẹ',
      );

      final incidentsProv = IncidentsProvider();
      final dashboardProv = DashboardProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<IncidentsProvider>.value(value: incidentsProv),
            ChangeNotifierProvider<DashboardProvider>.value(value: dashboardProv),
          ],
          child: MaterialApp(
            home: IncidentDetailScreen(incident: testIncident),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should NOT see Guardian action buttons
      expect(find.text(AppStrings.acknowledgeButton), findsNothing);
      expect(find.text(AppStrings.resolveButton), findsNothing);

      // Should see Calm Safety Card
      expect(find.byIcon(Icons.sensors_rounded), findsOneWidget);
      expect(find.text('Tín hiệu khẩn cấp đã được gửi tới người thân'), findsOneWidget);
    });

    testWidgets('2. Guardian viewing monitored user incident sees acknowledge and resolve buttons', (tester) async {
      await LocalStorage.saveAuth(
        accessToken: 'mock_token_g',
        refreshToken: 'mock_refresh_g',
        userId: 'guardian-456',
        email: 'guardian@test.com',
        fullName: 'Con Cái',
      );

      final incidentsProv = IncidentsProvider();
      final dashboardProv = DashboardProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<IncidentsProvider>.value(value: incidentsProv),
            ChangeNotifierProvider<DashboardProvider>.value(value: dashboardProv),
          ],
          child: MaterialApp(
            home: IncidentDetailScreen(incident: testIncident),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Guardian MUST see action buttons
      expect(find.text(AppStrings.acknowledgeButton), findsOneWidget);
      expect(find.text(AppStrings.resolveButton), findsOneWidget);
    });
  });
}
