import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/enums.dart';
import '../../core/models/relationship_model.dart';
import '../../core/widgets/calm_empty_state.dart';
import '../../core/widgets/calm_error_card.dart';
import '../../core/widgets/calm_loading_widget.dart';
import '../monitoring/monitoring_settings_screen.dart';
import '../pairing/qr_scanner_screen.dart';
import '../demo/showcase_demo_mode.dart';
import 'dashboard_provider.dart';

class MonitorView extends StatelessWidget {
  const MonitorView({super.key});

  Color _getStateColor(MonitoringState state) {
    switch (state) {
      case MonitoringState.ACTIVE:
      case MonitoringState.RESOLVED:
        return AppColors.stateActive;
      case MonitoringState.CHECK_IN_REQUIRED:
        return AppColors.stateCheckInRequired;
      case MonitoringState.WARNING:
      case MonitoringState.CHECK_IN_PENDING:
      case MonitoringState.GRACE_PERIOD:
        return AppColors.stateGracePeriod;
      case MonitoringState.ESCALATED:
      case MonitoringState.ALERT_TRIGGERED:
        return AppColors.stateAlertTriggered;
      case MonitoringState.ACKNOWLEDGED:
        return AppColors.stateAcknowledged;
      case MonitoringState.SUSPENDED:
      case MonitoringState.PAUSED:
      case MonitoringState.INACTIVE_MONITORING:
      case MonitoringState.INITIALIZING:
        return AppColors.statePaused;
    }
  }

  String _getStateLabel(MonitoringState state, BuildContext context) {
    switch (state) {
      case MonitoringState.ACTIVE:
      case MonitoringState.RESOLVED:
        return context.tr('state_active', fallback: AppStrings.stateActive);
      case MonitoringState.CHECK_IN_REQUIRED:
        return context.tr('state_check_in_required', fallback: AppStrings.stateCheckInRequired);
      case MonitoringState.WARNING:
      case MonitoringState.CHECK_IN_PENDING:
      case MonitoringState.GRACE_PERIOD:
        return context.tr('state_grace_period', fallback: AppStrings.stateGracePeriod);
      case MonitoringState.ESCALATED:
      case MonitoringState.ALERT_TRIGGERED:
        return context.tr('state_alert_triggered', fallback: AppStrings.stateAlertTriggered);
      case MonitoringState.ACKNOWLEDGED:
        return context.tr('state_acknowledged', fallback: AppStrings.stateAcknowledged);
      case MonitoringState.SUSPENDED:
      case MonitoringState.PAUSED:
        return context.tr('state_paused', fallback: AppStrings.statePaused);
      default:
        return context.tr('guardian_stable', fallback: AppStrings.guardianStable);
    }
  }

  void _showAddRelativeDialog(BuildContext context) {
    final inviteController = TextEditingController();
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('guardian_add_dialog_title', fallback: 'Thêm người thân theo dõi')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                key: const Key('scan_qr_button'),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final res = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                  );
                  if (res == true) {
                    dashboard.fetchDashboardData();
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(ctx.tr('guardian_scan_qr', fallback: 'Quét mã QR người thân')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      ctx.tr('guardian_or_enter_code', fallback: 'Or enter code'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ctx.tr('guardian_add_dialog_desc', fallback: 'Nhập mã ghép đôi từ người thân của bạn'),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: inviteController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: ctx.tr('guardian_add_dialog_hint', fallback: 'VD: CR-ABC12345'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.tr('common_cancel', fallback: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = inviteController.text.trim();
              if (code.isNotEmpty) {
                final ok = await dashboard.acceptInviteCode(code);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  final errorMsg = dashboard.getErrorMessage(context) ??
                      context.tr('guardian_connect_failed', fallback: 'Invalid or expired invitation code.');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? context.tr('guardian_connect_success', fallback: 'Connected successfully!')
                          : errorMsg),
                      backgroundColor: ok ? AppColors.stateActive : AppColors.stateAlertTriggered,
                    ),
                  );
                }
              }
            },
            child: Text(ctx.tr('guardian_connect_button', fallback: 'Connect')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);

    if (dashboard.isLoading && dashboard.monitoredByMe.isEmpty) {
      return CalmLoadingWidget(message: context.tr('guardian_loading', fallback: 'Loading relatives list...'));
    }

    return RefreshIndicator(
      onRefresh: () => dashboard.fetchDashboardData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (dashboard.errorMessage != null) ...[
              CalmErrorCard(
                message: dashboard.errorMessage!,
                onRetry: () => dashboard.fetchDashboardData(),
              ),
              const SizedBox(height: 12),
            ],

            // Top Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('guardian_monitored_by_me',
                      args: {'count': '${dashboard.monitoredByMe.length}'},
                      fallback: 'Monitoring (${dashboard.monitoredByMe.length})'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddRelativeDialog(context),
                  icon: const Icon(Icons.person_add_alt_1, size: 20),
                  label: Text(context.tr('guardian_add_person', fallback: 'Add person')),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (dashboard.monitoredByMe.isEmpty && !ShowcaseDemoController().isDemoActive)
              CalmEmptyState(
                icon: Icons.people_outline,
                title: context.tr('guardian_empty_title', fallback: 'No loved ones connected'),
                description: context.tr('guardian_empty_desc',
                    fallback: 'Connect with parents or relatives living alone to receive safety updates.'),
                action: ElevatedButton.icon(
                  onPressed: () => _showAddRelativeDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_link, size: 18),
                  label: Text(context.tr('guardian_connect_relative', fallback: 'Connect Relative')),
                ),
              )
            else if (ShowcaseDemoController().isDemoActive && dashboard.monitoredByMe.isEmpty)
              _buildDemoPersonCard(context)
            else
              ...dashboard.monitoredByMe.map((rel) => _buildMonitoredPersonCard(context, rel)),

          ],
        ),
      ),
    );
  }

  Widget _buildMonitoredPersonCard(BuildContext context, RelationshipModel rel) {
    final monitoredUser = rel.monitoredUser;
    final config = rel.config;
    final state = config?.currentState ?? MonitoringState.ACTIVE;
    final stateColor = _getStateColor(state);
    final lastActivity = config?.lastMeaningfulActivityAt;

    final formattedLastActivity = lastActivity != null
        ? DateFormat('HH:mm dd/MM').format(lastActivity.toLocal())
        : context.tr('guardian_no_activity', fallback: 'No activity yet');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: state == MonitoringState.ALERT_TRIGGERED ||
                  state == MonitoringState.ESCALATED ||
                  state == MonitoringState.WARNING ||
                  state == MonitoringState.GRACE_PERIOD
              ? stateColor.withAlpha(100)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name, Label & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.secondaryLight,
                  child: Text(
                    (monitoredUser?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monitoredUser?.fullName ?? context.tr('monitored_relative_default', fallback: 'Relative'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (rel.label != null && rel.label!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          rel.label!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Status pill with ample breathing space
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: stateColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: stateColor.withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: stateColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _getStateLabel(state, context),
                                style: TextStyle(
                                  color: stateColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),

            // Footer: Last activity info & Action button
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('state_last_activity',
                          args: {'time': formattedLastActivity},
                          fallback: 'Last activity: $formattedLastActivity'),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MonitoringSettingsScreen(relationship: rel),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: Text(context.tr('guardian_schedule_and_config', fallback: 'Schedule & Config'), style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoPersonCard(BuildContext context) {
    final demoController = ShowcaseDemoController();
    final state = demoController.simulatedState;
    final stateColor = _getStateColor(state);
    final lastActivity = DateFormat('HH:mm - dd/MM').format(demoController.lastSimulatedActivity.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: stateColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryLight,
                  child: const Text('M', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('demo_guardian_relative_name', fallback: 'Mom (Nguyen Thi Mai)'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('demo_guardian_relative_status', fallback: 'Monitored & Safe'),
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: stateColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: stateColor.withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: stateColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _getStateLabel(state, context),
                                style: TextStyle(color: stateColor, fontWeight: FontWeight.bold, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.battery_charging_full, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  context.tr('demo_guardian_relative_battery', fallback: 'Battery: 92% (Charging)'),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  context.tr('demo_guardian_relative_last_activity',
                      args: {'time': lastActivity},
                      fallback: 'Recent: $lastActivity'),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

