import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/enums.dart';
import '../../core/models/schedule_window_model.dart';
import '../../core/storage/local_storage.dart';
import '../../core/widgets/calm_error_card.dart';
import '../../core/widgets/evenear_illustrations.dart';
import '../auth/auth_provider.dart';
import '../check_in/check_in_screen.dart';
import '../check_in/recent_activities_screen.dart';
import '../devices/devices_screen.dart';
import '../monitoring/monitoring_settings_screen.dart';
import 'dashboard_provider.dart';

class MonitoredView extends StatefulWidget {
  const MonitoredView({super.key});

  @override
  State<MonitoredView> createState() => _MonitoredViewState();
}

class _MonitoredViewState extends State<MonitoredView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  final Battery _battery = Battery();
  int? _batteryLevel;
  bool _isCheckingIn = false;
  Map<String, dynamic>? _selfMonitoringConfig;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    final isTestEnv = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!isTestEnv) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }

    _pulseScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadSelfMonitoringConfig();
    _loadBattery();
  }

  Future<void> _loadBattery() async {
    final isTestEnv = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (isTestEnv) return;
    try {
      final level = await _battery.batteryLevel;
      if (mounted && level >= 0 && level <= 100) {
        setState(() => _batteryLevel = level);
      }
    } catch (_) {}
  }

  Future<void> _loadSelfMonitoringConfig() async {
    final cfg = await LocalStorage.getSelfMonitoringConfig();
    if (mounted && cfg != null) {
      setState(() {
        _selfMonitoringConfig = cfg;
      });
    }
  }

  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  bool _isWithinActiveWindow(ScheduleWindowModel window, DateTime dt) {
    if (!window.isEnabled) return false;
    final currentMinutes = dt.hour * 60 + dt.minute;
    final start = _timeToMinutes(window.startTime);
    final end = _timeToMinutes(window.endTime);
    if (start <= end) {
      return currentMinutes >= start && currentMinutes < end;
    } else {
      return currentMinutes >= start || currentMinutes < end;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getStateLabel(MonitoringState state, BuildContext context) {
    switch (state) {
      case MonitoringState.ACTIVE:
      case MonitoringState.RESOLVED:
        return context.tr('state_active');
      case MonitoringState.CHECK_IN_REQUIRED:
        return context.tr('state_check_in_required');
      case MonitoringState.WARNING:
      case MonitoringState.CHECK_IN_PENDING:
      case MonitoringState.GRACE_PERIOD:
        return context.tr('state_grace_period');
      case MonitoringState.ESCALATED:
      case MonitoringState.ALERT_TRIGGERED:
        return context.tr('state_alert_triggered');
      case MonitoringState.ACKNOWLEDGED:
        return context.tr('state_acknowledged');
      case MonitoringState.SUSPENDED:
      case MonitoringState.PAUSED:
        return context.tr('state_paused');
      default:
        return context.tr('state_active');
    }
  }

  Future<void> _handleOneTouchCheckIn(DashboardProvider dashboard) async {
    if (_isCheckingIn) return;
    setState(() => _isCheckingIn = true);

    void showCheckInError() {
      final errorMsg = context.tr(
        'check_in_error',
        fallback: 'Không thể gửi xác nhận. Vui lòng thử lại.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppColors.danger,
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(errorMsg)),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    try {
      final success = await dashboard.sendCheckIn();
      if (!mounted) return;
      if (success) {
        final message = dashboard.lastCheckInOffline
            ? context.tr('check_in_offline_success')
            : context.tr('check_in_success');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: AppColors.stateActive,
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CheckInScreen(confirmedAt: DateTime.now()),
          ),
        );
      } else {
        showCheckInError();
      }
    } catch (e) {
      if (mounted) {
        showCheckInError();
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
    AuthProvider? auth;
    try {
      auth = Provider.of<AuthProvider>(context);
    } catch (_) {}

    final fullName = auth?.currentUser?.fullName ?? '';
    final shortName = fullName.trim().isNotEmpty
        ? fullName.trim().split(' ').last
        : '';
    final greetingText = shortName.isNotEmpty
        ? context.tr(
            'monitored_greeting_name',
            args: {'name': shortName},
            fallback: 'Xin chào, $shortName 👋',
          )
        : context.tr('monitored_greeting_generic', fallback: 'Xin chào 👋');
    final currentState = dashboard.myCurrentState;
    final stateLabel = _getStateLabel(currentState, context);

    final lastActivity = dashboard.monitoringMe.isNotEmpty &&
            dashboard.monitoringMe.first.config?.lastActivityAt != null
        ? dashboard.monitoringMe.first.config!.lastActivityAt
        : null;
    final lastActivityTime = lastActivity != null
        ? context.tr(
            'monitored_today_at',
            args: {'time': DateFormat('HH:mm').format(lastActivity.toLocal())},
            fallback: 'Hôm nay ${DateFormat('HH:mm').format(lastActivity.toLocal())}',
          )
        : context.tr('monitored_no_activity_yet', fallback: 'Chưa có hoạt động');

    List<ScheduleWindowModel> windows = [];
    if (dashboard.monitoringMe.isNotEmpty) {
      windows = dashboard.monitoringMe.first.config?.scheduleWindows ?? [];
    }
    if (windows.isEmpty && _selfMonitoringConfig != null) {
      final rawWindows = _selfMonitoringConfig!['scheduleWindows'] ??
          _selfMonitoringConfig!['schedule_windows'];
      if (rawWindows is List) {
        for (final item in rawWindows) {
          if (item is Map) {
            windows.add(
              ScheduleWindowModel.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
    }

    final now = DateTime.now();
    final todayDayOfWeek = now.weekday % 7;
    ScheduleWindowModel? todayWindow;
    for (final w in windows) {
      if (w.dayOfWeek == todayDayOfWeek) {
        todayWindow = w;
        break;
      }
    }
    if (todayWindow == null && windows.isNotEmpty) {
      todayWindow = windows.first;
    }

    String scheduleWindowsText;
    String? complianceStatusText;
    bool isWithinActive = true;

    if (todayWindow != null) {
      scheduleWindowsText = '${todayWindow.startTime} - ${todayWindow.endTime}';
      if (!todayWindow.isEnabled) {
        complianceStatusText = context.tr(
          'monitored_schedule_off_today',
          fallback: 'Khung giờ hôm nay đang tắt',
        );
        isWithinActive = false;
      } else if (_isWithinActiveWindow(todayWindow, now)) {
        complianceStatusText = context.tr(
          'monitored_schedule_active_now',
          fallback: 'Đang trong khung giờ hoạt động',
        );
        isWithinActive = true;
      } else {
        complianceStatusText = context.tr(
          'monitored_schedule_resting_now',
          fallback: 'Khung giờ nghỉ ngơi (đóng băng bộ đếm)',
        );
        isWithinActive = false;
      }
    } else {
      scheduleWindowsText = context.tr(
        'monitored_schedule_not_set',
        fallback: 'Chưa thiết lập khung giờ',
      );
      complianceStatusText = null;
      isWithinActive = false;
    }

    final batteryDisplay = _batteryLevel != null ? '$_batteryLevel%' : '--%';

    return Material(
      type: MaterialType.transparency,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await dashboard.fetchDashboardData();
          await _loadSelfMonitoringConfig();
          await _loadBattery();
        },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
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

                // Header Greeting Row matching 09_monitored_dashboard.png: "Xin chào, An 👋" + "🟢 Bạn đang được bảo vệ"
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greetingText,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF184A3E),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Color(0xFF43A071),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            stateLabel,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4A6B61),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Large Concentric Green Circle Check-in Button ("Tôi vẫn ổn" / "Nhấn để xác nhận")
                Center(
                  child: GestureDetector(
                    onTap: _isCheckingIn
                        ? null
                        : () => _handleOneTouchCheckIn(dashboard),
                    child: RepaintBoundary(
                      child: ScaleTransition(
                        scale: _pulseScale,
                        child: Container(
                          width: 224,
                          height: 224,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFE3EFE9),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFCDE3D7),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF3A8564),
                                    Color(0xFF28694C),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF28694C).withValues(
                                      alpha: 0.24,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isCheckingIn)
                                        const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      else ...[
                                        const Icon(
                                          Icons.verified_user_outlined,
                                          color: Colors.white,
                                          size: 38,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          context.tr('check_in_button'),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          context.tr('check_in_sub_prompt'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFFE2F1EA),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Two side-by-side status cards (09_monitored_dashboard.png): Lần hoạt động gần nhất | Pin thiết bị
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RecentActivitiesScreen(
                                  showAppBar: true,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE8ECE8)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF184A3E).withValues(alpha: 0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr(
                                    'monitored_last_activity_title',
                                    fallback: 'Lần hoạt động gần nhất',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF4A6B61),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  lastActivityTime,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF184A3E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr(
                                    'monitored_synced_status',
                                    fallback: '(Đã đồng bộ)',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF4A6B61),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DevicesScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE8ECE8)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF184A3E).withValues(alpha: 0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr(
                                    'monitored_device_battery_title',
                                    fallback: 'Pin thiết bị',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF4A6B61),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.battery_5_bar_rounded,
                                      color: Color(0xFF2E7D60),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        batteryDisplay,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF184A3E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Lịch kiểm tra Card ("09:00 - 12:00  •  15:00 - 18:00" matching 09_monitored_dashboard.png)
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    final rel = dashboard.monitoringMe.isNotEmpty
                        ? dashboard.monitoringMe.first
                        : null;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MonitoringSettingsScreen(relationship: rel),
                      ),
                    ).then((val) {
                      if (val == true) {
                        _loadSelfMonitoringConfig();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE8ECE8)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF184A3E).withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                context.tr(
                                  'monitored_check_schedule_title',
                                  fallback: 'Lịch kiểm tra',
                                ),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF4A6B61),
                                ),
                              ),
                            ),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    dashboard.monitoringMe.isEmpty
                                        ? Icons.tune_rounded
                                        : Icons.nightlight_round,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      context.tr('monitored_sleep_schedule_action'),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          scheduleWindowsText,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF184A3E),
                          ),
                        ),
                        if (complianceStatusText != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isWithinActive
                                      ? const Color(0xFF43A071)
                                      : const Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  complianceStatusText,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: isWithinActive
                                        ? const Color(0xFF2D6A4F)
                                        : const Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                if (dashboard.monitoringMe.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final rel in dashboard.monitoringMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MonitoringSettingsScreen(
                                  relationship: rel,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE8ECE8)),
                            ),
                            child: Row(
                              children: [
                                EvenearAvatar(
                                  name:
                                      rel.monitorUser?.fullName ??
                                      rel.label ??
                                      context.tr('relationship_family_member'),
                                  radius: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rel.monitorUser?.fullName ??
                                            rel.label ??
                                            context.tr('relationship_family_member'),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (rel.config?.isPaused ?? false)
                                            ? context.tr(
                                                'monitoring_paused_short',
                                                fallback: 'Đang tạm dừng',
                                              )
                                            : context.tr(
                                                'monitoring_auto_active',
                                                fallback: 'Đang tự động theo dõi',
                                              ),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: (rel.config?.isPaused ?? false)
                                              ? AppColors.textMuted
                                              : AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => MonitoringSettingsScreen(
                                          relationship: rel,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.tune_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onSelected: (val) async {
                                    if (val == 'pause') {
                                      await dashboard.pauseMonitoring(
                                        rel.id,
                                        durationMinutes: 120,
                                      );
                                    } else if (val == 'resume') {
                                      await dashboard.resumeMonitoring(rel.id);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    if (!(rel.config?.isPaused ?? false))
                                      PopupMenuItem(
                                        value: 'pause',
                                        child: Text(
                                          ctx.tr(
                                            'monitoring_pause_2h',
                                            fallback: 'Tạm dừng theo dõi (2 giờ)',
                                          ),
                                        ),
                                      ),
                                    if (rel.config?.isPaused ?? false)
                                      PopupMenuItem(
                                        value: 'resume',
                                        child: Text(
                                          ctx.tr(
                                            'monitoring_resume',
                                            fallback: 'Tiếp tục theo dõi',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
