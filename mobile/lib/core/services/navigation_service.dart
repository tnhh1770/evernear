import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/dashboard/dashboard_provider.dart';
import '../../features/incidents/incident_detail_screen.dart';

/// Centralized navigation service to support deep linking and notification action routing
/// without requiring a BuildContext at the invocation point.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Handles incoming FCM / notification tap payload and performs context-safe routing.
  static Future<bool> handleNotificationPayload(Map<String, dynamic> data) async {
    debugPrint('[NavigationService] Handling notification payload: $data');

    final incidentId = data['incidentId']?.toString() ?? data['incident_id']?.toString();
    final type = data['type']?.toString();

    final navState = navigatorKey.currentState;
    final context = navigatorKey.currentContext;

    // 1. Direct navigation to Incident Detail Screen
    if (incidentId != null && incidentId.isNotEmpty) {
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => IncidentDetailScreen(incidentId: incidentId),
          ),
        );
        return true;
      }
    }

    // 2. Navigation / Tab switch for Check-in confirmations or general incident updates
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
