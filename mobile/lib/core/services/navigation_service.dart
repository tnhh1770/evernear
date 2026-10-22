import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/check_in/check_in_screen.dart';
import '../../features/dashboard/dashboard_provider.dart';
import '../../features/incidents/incident_detail_screen.dart';
import '../../features/pairing/qr_invite_screen.dart';

/// Centralized navigation service to support deep linking and notification action routing
/// without requiring a BuildContext at the invocation point.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Navigates to a named route globally using [navigatorKey].
  static Future<dynamic>? navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState?.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  /// Handles incoming FCM / notification tap payload or deep-link data and performs context-safe routing.
  static Future<bool> handleNotificationPayload(Map<String, dynamic> data) async {
    debugPrint('[NavigationService] Handling notification payload: $data');

    final incidentId = data['incidentId']?.toString() ?? data['incident_id']?.toString();
    final inviteCode = data['inviteCode']?.toString() ?? data['invite_code']?.toString() ?? data['code']?.toString();
    final type = data['type']?.toString();
    final action = data['action']?.toString();
    final route = data['route']?.toString();

    final navState = navigatorKey.currentState;
    final context = navigatorKey.currentContext;

    // 1. Direct navigation to CheckInScreen for check-in prompts ("Bạn vẫn ổn chứ?")
    if (type == 'CHECK_IN_PROMPT' || action == 'CHECK_IN') {
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const CheckInScreen(),
          ),
        );
        return true;
      }
    }

    // 2. Direct navigation to Incident Detail Screen for active incidents
    if (incidentId != null && incidentId.isNotEmpty && type != 'INCIDENT_RESOLVED') {
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => IncidentDetailScreen(incidentId: incidentId),
          ),
        );
        return true;
      }
    }

    // 3. Direct navigation for pairing invite codes
    if (inviteCode != null && inviteCode.isNotEmpty) {
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => QrInviteScreen(initialCode: inviteCode),
          ),
        );
        return true;
      }
    }

    // 4. Explicit named route in payload
    if (route != null && route.isNotEmpty && navState != null) {
      navState.pushNamed(route);
      return true;
    }

    // 5. Navigation / Tab switch for Check-in confirmations or general incident updates
    if (type == 'CHECK_IN_CONFIRMED' ||
        type == 'CHECK_IN_PROMPT' ||
        type == 'INCIDENT_RESOLVED' ||
        type == 'INCIDENT_CREATED') {
      if (context != null) {
        try {
          final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
          // Tab index 2 is Incidents & Check-ins Notification feed
          dashboardProvider.setSelectedTabIndex(2);

          // Pop any open modals or dialogs back to the root if appropriate
          if (navState != null && navState.canPop()) {
            navState.popUntil((route) => route.isFirst);
          }
          return true;
        } catch (e) {
          debugPrint('[NavigationService] Error updating dashboard tab: $e');
        }
      }
    }

    return false;
  }
}
