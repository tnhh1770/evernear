import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/enums.dart';
import '../../core/widgets/calm_error_card.dart';
import '../../core/widgets/calm_loading_widget.dart';
import '../check_in/check_in_screen.dart';
import '../demo/showcase_demo_mode.dart';
import '../monitoring/monitoring_settings_screen.dart';
import '../pairing/qr_invite_screen.dart';
import 'dashboard_provider.dart';

class MonitoredView extends StatefulWidget {
  const MonitoredView({super.key});

  @override
  State<MonitoredView> createState() => _MonitoredViewState();
}

class _MonitoredViewState extends State<MonitoredView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    final isTestEnv = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }

    _pulseScale = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseOpacity = Tween<double>(begin: 0.35, end: 0.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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

  IconData _getStateIcon(MonitoringState state) {
    switch (state) {
      case MonitoringState.ACTIVE:
      case MonitoringState.RESOLVED:
        return Icons.shield;
      case MonitoringState.CHECK_IN_REQUIRED:
        return Icons.access_time_filled;
      case MonitoringState.WARNING:
      case MonitoringState.CHECK_IN_PENDING:
      case MonitoringState.GRACE_PERIOD:
        return Icons.notifications_active;
      case MonitoringState.ESCALATED:
      case MonitoringState.ALERT_TRIGGERED:
        return Icons.warning_amber_rounded;
      case MonitoringState.ACKNOWLEDGED:
        return Icons.favorite;
      case MonitoringState.SUSPENDED:
      case MonitoringState.PAUSED:
      case MonitoringState.INACTIVE_MONITORING:
      case MonitoringState.INITIALIZING:
        return Icons.pause_circle_filled;
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

  String _getStateDescription(MonitoringState state, BuildContext context) {
    switch (state) {
      case MonitoringState.ACTIVE:
      case MonitoringState.RESOLVED:
        return context.tr('state_active_desc', fallback: AppStrings.stateActiveDesc);
      case MonitoringState.CHECK_IN_REQUIRED:
        return context.tr('state_check_in_required_desc', fallback: AppStrings.stateCheckInRequiredDesc);
      case MonitoringState.WARNING:
      case MonitoringState.CHECK_IN_PENDING:
      case MonitoringState.GRACE_PERIOD:
        return context.tr('state_grace_period_desc', fallback: AppStrings.stateGracePeriodDesc);
      case MonitoringState.ESCALATED:
      case MonitoringState.ALERT_TRIGGERED:
        return context.tr('state_alert_triggered_desc', fallback: AppStrings.stateAlertTriggeredDesc);
      case MonitoringState.SUSPENDED:
      case MonitoringState.PAUSED:
        return context.tr('state_paused_desc', fallback: AppStrings.statePausedDesc);
      default:
        return context.tr('state_active_desc', fallback: AppStrings.stateActiveDesc);
    }
  }

  Future<void> _handleOneTouchCheckIn(
    DashboardProvider dashboard,
    ShowcaseDemoController demoController,
  ) async {
    if (demoController.isDemoActive) {
      demoController.performQuickDemoCheckIn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(context.tr('demo_check_in_success', fallback: 'Peace of mind check-in confirmed! (Demo Simulation)')),
                ),
              ],
            ),
            backgroundColor: AppColors.stateActive,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (_isCheckingIn) return;
    setState(() => _isCheckingIn = true);

    try {
      final success = await dashboard.sendCheckIn();
      if (mounted) {
        if (success) {
          final message = dashboard.lastCheckInOffline
              ? context.tr('check_in_offline_success', fallback: AppStrings.checkInOfflineSuccess)
              : context.tr('check_in_success', fallback: AppStrings.checkInSuccess);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: AppColors.stateActive,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(message)),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(context.tr('check_in_error', fallback: 'Safety confirmation saved locally. Will sync automatically once online.')),
                  ),
                ],
              ),
              backgroundColor: AppColors.stateAlertTriggered,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);
    final demoController = ShowcaseDemoController();

    if (dashboard.isLoading && dashboard.monitoringMe.isEmpty && !demoController.isDemoActive) {
      return CalmLoadingWidget(message: context.tr('common_loading', fallback: 'Status stable'));
    }

    final currentState = demoController.isDemoActive ? demoController.simulatedState : dashboard.myCurrentState;
    final stateColor = _getStateColor(currentState);
    final lastActivity = demoController.isDemoActive ? demoController.lastSimulatedActivity : dashboard.myLastActivityAt;

    final formattedLastActivity = lastActivity != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format(lastActivity.toLocal())
        : context.tr('state_no_data', fallback: 'No data yet');

    return RefreshIndicator(
      onRefresh: () => dashboard.fetchDashboardData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (dashboard.errorMessage != null && !demoController.isDemoActive) ...[
              CalmErrorCard(
                message: dashboard.errorMessage!,
                onRetry: () => dashboard.fetchDashboardData(),
              ),
              const SizedBox(height: 12),
            ],

            // Hero Breathing Halo Status Showcase
            Center(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer breathing pulse ring
                        Transform.scale(
                          scale: _pulseScale.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: stateColor.withValues(alpha: _pulseOpacity.value),
                            ),
                          ),
                        ),
                        // Mid glow ring
                        Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stateColor.withValues(alpha: 0.12),
                            border: Border.all(
                              color: stateColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                        ),
                        // Inner solid orb
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: stateColor.withValues(alpha: 0.25),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _getStateIcon(currentState),
                              size: 44,
                              color: stateColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Status Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: stateColor.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
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
                        const SizedBox(width: 8),
                        Text(
                          _getStateLabel(currentState, context),
                          style: TextStyle(
                            color: stateColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _getStateDescription(currentState, context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Last activity info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.tr('state_last_activity',
                              args: {'time': formattedLastActivity},
                              fallback: 'Last activity: $formattedLastActivity'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Hero "I'm Okay" One-Touch Action Button + Note shortcut
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isCheckingIn ? null : () => _handleOneTouchCheckIn(dashboard, demoController),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      shadowColor: AppColors.primary.withValues(alpha: 0.35),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isCheckingIn)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        else
                          const Icon(Icons.favorite, size: 24, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          context.tr('check_in_button', fallback: AppStrings.checkInButton),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Detailed check-in / note shortcut button
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: IconButton(
                    tooltip: context.tr('check_in_title', fallback: 'Safety Check-in'),
                    icon: const Icon(Icons.edit_note_rounded, size: 28, color: AppColors.primary),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CheckInScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Promotional Share & Invite Card ("Share Peace of Mind")
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8F5E9), Color(0xFFF1F8F4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.qr_code_2, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('monitored_share_title', fallback: 'I am okay'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('monitored_share_desc', fallback: 'Invite loved ones or housemates to connect with a single QR code.'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const QrInviteScreen()),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('monitored_create_invite_btn', fallback: 'Create Invite Code'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Monitoring Relatives Section
            Text(
              context.tr('guardian_relatives_title',
                  args: {'count': '${dashboard.monitoringMe.length}'},
                  fallback: 'Supervising Loved Ones (${dashboard.monitoringMe.length})'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            if (dashboard.monitoringMe.isEmpty && !demoController.isDemoActive)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.group_add_outlined, size: 36, color: AppColors.textMuted),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('guardian_no_relatives',
                          fallback: 'You have not connected with any relatives yet.'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const QrInviteScreen()),
                        );
                      },
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: Text(context.tr('monitored_invite_btn', fallback: 'Invite Loved One Now')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: () {
                  if (dashboard.monitoringMe.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MonitoringSettingsScreen(
                          relationship: dashboard.monitoringMe.first,
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QrInviteScreen()),
                    );
                  }
                },
                icon: const Icon(Icons.nightlight_round, size: 18),
                label: Text(context.tr('monitored_sleep_schedule_btn', fallback: 'Sleep & Monitoring Schedule Settings')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primaryLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              ...dashboard.monitoringMe.map((rel) {
                final monitor = rel.monitorUser;
                final isPaused = rel.config?.isPaused ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  color: AppColors.surface,
                  child: ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MonitoringSettingsScreen(relationship: rel),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        (monitor?.fullName ?? 'N').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      monitor?.fullName ?? context.tr('monitored_relative_default', fallback: 'Relative'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      isPaused
                          ? context.tr('guardian_status_paused', fallback: 'Currently paused')
                          : context.tr('guardian_status_auto', fallback: 'Auto-monitoring active'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPaused ? AppColors.statePaused : AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                          tooltip: context.tr('monitored_schedule_tooltip', fallback: 'Sleep & Monitoring Schedule'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MonitoringSettingsScreen(relationship: rel),
                              ),
                            );
                          },
                        ),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'pause') {
                              dashboard.pauseMonitoring(rel.id, durationMinutes: 120);
                            } else if (val == 'resume') {
                              dashboard.resumeMonitoring(rel.id);
                            } else if (val == 'settings') {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MonitoringSettingsScreen(relationship: rel),
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'settings',
                              child: Row(
                                children: [
                                  const Icon(Icons.tune_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(context.tr('monitored_schedule_tooltip', fallback: 'Sleep & Monitoring Schedule')),
                                ],
                              ),
                            ),
                            if (!isPaused)
                              PopupMenuItem(
                                value: 'pause',
                                child: Row(
                                  children: [
                                    const Icon(Icons.pause, size: 18),
                                    const SizedBox(width: 8),
                                    Text(context.tr('guardian_pause_2h', fallback: 'Pause for 2 hours')),
                                  ],
                                ),
                              )
                            else
                              PopupMenuItem(
                                value: 'resume',
                                child: Row(
                                  children: [
                                    const Icon(Icons.play_arrow, size: 18),
                                    const SizedBox(width: 8),
                                    Text(context.tr('guardian_resume', fallback: 'Resume monitoring')),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),

            // Privacy Guarantee Footnote
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.chipBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('monitored_privacy_pledge',
                          fallback: 'Carely guarantees 100% no camera, no microphone, and no continuous GPS tracking. Your privacy is always paramount.'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
