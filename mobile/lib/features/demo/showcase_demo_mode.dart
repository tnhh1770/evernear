import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/enums.dart';
import '../../core/i18n/app_localizations.dart';

/// Provides a quick interactive state switcher for marketing demos,
/// screen recordings, and promotional presentations.
class ShowcaseDemoController extends ChangeNotifier {
  static final ShowcaseDemoController _instance = ShowcaseDemoController._internal();
  factory ShowcaseDemoController() => _instance;
  ShowcaseDemoController._internal();

  bool _isDemoActive = false;
  MonitoringState _simulatedState = MonitoringState.ACTIVE;
  DateTime _lastSimulatedActivity = DateTime.now().subtract(const Duration(minutes: 14));
  final int _simulatedBattery = 88;

  bool get isDemoActive => _isDemoActive;
  MonitoringState get simulatedState => _simulatedState;
  DateTime get lastSimulatedActivity => _lastSimulatedActivity;
  int get simulatedBattery => _simulatedBattery;

  void enableDemo({MonitoringState initial = MonitoringState.ACTIVE}) {
    _isDemoActive = true;
    _simulatedState = initial;
    notifyListeners();
  }

  void disableDemo() {
    _isDemoActive = false;
    notifyListeners();
  }

  void setSimulatedState(MonitoringState state) {
    _simulatedState = state;
    if (state == MonitoringState.ACTIVE || state == MonitoringState.RESOLVED) {
      _lastSimulatedActivity = DateTime.now().subtract(const Duration(minutes: 5));
    } else if (state == MonitoringState.CHECK_IN_REQUIRED) {
      _lastSimulatedActivity = DateTime.now().subtract(const Duration(hours: 12, minutes: 30));
    } else if (state == MonitoringState.ALERT_TRIGGERED) {
      _lastSimulatedActivity = DateTime.now().subtract(const Duration(hours: 24, minutes: 15));
    }
    notifyListeners();
  }

  void performQuickDemoCheckIn() {
    _simulatedState = MonitoringState.ACTIVE;
    _lastSimulatedActivity = DateTime.now();
    notifyListeners();
  }
}

/// Floating Banner & Control Modal for live pitch demos
class ShowcaseDemoBanner extends StatelessWidget {
  const ShowcaseDemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ShowcaseDemoController(),
      builder: (context, _) {
        final controller = ShowcaseDemoController();
        if (!controller.isDemoActive) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'DEMO MODE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF332000),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('demo_banner_simulating',
                      args: {'state': _stateName(controller.simulatedState, context)},
                      fallback: 'Simulating: ${_stateName(controller.simulatedState, context)}'),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _showStateSelector(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('demo_change_state', fallback: 'Change State'),
                      style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => controller.disableDemo(),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showStateSelector(BuildContext context) {
    final controller = ShowcaseDemoController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ctx.tr('demo_state_picker_title', fallback: 'Showcase State Simulation'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ctx.tr('demo_state_picker_desc', fallback: 'Select the state you wish to demonstrate:'),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _demoStateTile(
                  ctx,
                  title: ctx.tr('demo_state_active_title', fallback: '1. Safe & Normal (ACTIVE)'),
                  desc: ctx.tr('demo_state_active_desc', fallback: 'Calm green state, normal daily activity'),
                  color: AppColors.stateActive,
                  icon: Icons.check_circle_outline,
                  onTap: () {
                    controller.setSimulatedState(MonitoringState.ACTIVE);
                    Navigator.pop(ctx);
                  },
                ),
                _demoStateTile(
                  ctx,
                  title: ctx.tr('demo_state_checkin_title', fallback: '2. Check-in Needed (CHECK_IN_REQUIRED)'),
                  desc: ctx.tr('demo_state_checkin_desc', fallback: 'Inactivity window elapsed, prompting "Are you okay?"'),
                  color: AppColors.stateCheckInRequired,
                  icon: Icons.access_time,
                  onTap: () {
                    controller.setSimulatedState(MonitoringState.CHECK_IN_REQUIRED);
                    Navigator.pop(ctx);
                  },
                ),
                _demoStateTile(
                  ctx,
                  title: ctx.tr('demo_state_alert_title', fallback: '3. Alert Triggered (ALERT_TRIGGERED)'),
                  desc: ctx.tr('demo_state_alert_desc', fallback: 'No response received, escalating SMS/Push to guardians'),
                  color: AppColors.stateAlertTriggered,
                  icon: Icons.warning_amber_rounded,
                  onTap: () {
                    controller.setSimulatedState(MonitoringState.ALERT_TRIGGERED);
                    Navigator.pop(ctx);
                  },
                ),
                _demoStateTile(
                  ctx,
                  title: ctx.tr('demo_state_resolved_title', fallback: '4. Resolved & Recovered (RESOLVED)'),
                  desc: ctx.tr('demo_state_resolved_desc', fallback: 'User confirmed "I am okay", system returned to safe'),
                  color: AppColors.primary,
                  icon: Icons.favorite,
                  onTap: () {
                    controller.setSimulatedState(MonitoringState.RESOLVED);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _demoStateTile(
    BuildContext context, {
    required String title,
    required String desc,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.divider),
        ),
        tileColor: AppColors.background,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        onTap: onTap,
      ),
    );
  }

  static String _stateName(MonitoringState state, BuildContext context) {
    switch (state) {
      case MonitoringState.ACTIVE:
        return context.tr('state_active', fallback: 'Safe (Active)');
      case MonitoringState.CHECK_IN_REQUIRED:
        return context.tr('state_check_in_required', fallback: 'Check-in Required');
      case MonitoringState.ALERT_TRIGGERED:
      case MonitoringState.ESCALATED:
        return context.tr('state_alert_triggered', fallback: 'Family notified');
      case MonitoringState.RESOLVED:
        return context.tr('state_resolved', fallback: 'Support completed');
      default:
        return state.name;
    }
  }
}
