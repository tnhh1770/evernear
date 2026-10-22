import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/relationship_model.dart';
import '../../core/models/schedule_window_model.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../core/widgets/active_account_chip.dart';
import '../../core/widgets/calm_error_card.dart';
import '../auth/auth_provider.dart';
import '../dashboard/dashboard_provider.dart';

class MonitoringSettingsScreen extends StatefulWidget {
  final RelationshipModel? relationship;
  final int? initialSelectedDay;

  const MonitoringSettingsScreen({
    super.key,
    this.relationship,
    this.initialSelectedDay,
  });

  @override
  State<MonitoringSettingsScreen> createState() => _MonitoringSettingsScreenState();
}

class _MonitoringSettingsScreenState extends State<MonitoringSettingsScreen> {
  final ApiClient _apiClient = ApiClient();
  late int _inactivityThreshold;
  late int _checkInGracePeriod;
  late bool _locationEnabled;
  late String _timezone;
  late Map<int, ScheduleWindowModel> _windowsMap;
  late int _selectedDayOfWeek;
  List<String> _reminderTimes = ['09:00', '15:00', '20:00'];
  bool _isSaving = false;
  String? _saveErrorMessage;
  bool _isCustomGracePeriod = false;
  bool _pauseWhenTraveling = false;
  bool _lowBatteryAlert = true;

  // Weekday ordering for Vietnam: Monday (1) to Sunday (0)
  static const List<int> _dayOrder = [1, 2, 3, 4, 5, 6, 0];

  @override
  void initState() {
    super.initState();
    final config = widget.relationship?.config;
    _inactivityThreshold = config?.inactivityThresholdMinutes ?? 180;
    _checkInGracePeriod = config?.checkInGracePeriodMinutes ?? 30;
    _locationEnabled = config?.locationEnabled ?? true;
    _timezone = config?.timezone ?? 'Asia/Ho_Chi_Minh';

    final windows = config?.scheduleWindows ?? [];
    if (widget.initialSelectedDay != null) {
      _selectedDayOfWeek = widget.initialSelectedDay!;
    } else if (windows.isNotEmpty) {
      _selectedDayOfWeek = windows.first.dayOfWeek;
    } else {
      _selectedDayOfWeek = DateTime.now().weekday % 7;
    }

    _initWindows(windows);

    if (widget.relationship == null) {
      _loadSelfMonitoringConfig();
    }
  }

  Future<void> _loadSelfMonitoringConfig() async {
    final selfConfig = await LocalStorage.getSelfMonitoringConfig();
    if (selfConfig != null && mounted) {
      setState(() {
        if (selfConfig['inactivityThresholdMinutes'] != null) {
          final val = selfConfig['inactivityThresholdMinutes'];
          _inactivityThreshold = (val is num) ? val.toInt() : (int.tryParse('$val') ?? _inactivityThreshold);
        }
        if (selfConfig['checkInGraceMinutes'] != null) {
          final val = selfConfig['checkInGraceMinutes'];
          _checkInGracePeriod = (val is num) ? val.toInt() : (int.tryParse('$val') ?? _checkInGracePeriod);
        } else if (selfConfig['checkInGracePeriodMinutes'] != null) {
          final val = selfConfig['checkInGracePeriodMinutes'];
          _checkInGracePeriod = (val is num) ? val.toInt() : (int.tryParse('$val') ?? _checkInGracePeriod);
        }
        if (selfConfig['locationEnabled'] != null) {
          _locationEnabled = selfConfig['locationEnabled'] as bool;
        }
        if (selfConfig['timezone'] != null) {
          _timezone = selfConfig['timezone'].toString();
        }
        if (selfConfig['reminderTimes'] is List) {
          final parsed = (selfConfig['reminderTimes'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
          if (parsed.isNotEmpty) {
            _reminderTimes = parsed;
          }
        }
      if (selfConfig['pauseWhenTraveling'] is bool) {
          _pauseWhenTraveling = selfConfig['pauseWhenTraveling'] as bool;
        }
        if (selfConfig['lowBatteryAlert'] is bool) {
          _lowBatteryAlert = selfConfig['lowBatteryAlert'] as bool;
        }
        final rawWindows = selfConfig['scheduleWindows'] ?? selfConfig['schedule_windows'];
        if (rawWindows is List) {
          final List<ScheduleWindowModel> windows = [];
          for (final item in rawWindows) {
            if (item is Map) {
              windows.add(ScheduleWindowModel.fromJson(Map<String, dynamic>.from(item)));
            }
          }
          if (windows.isNotEmpty) {
            _initWindows(windows);
          }
        }
      });
    }
  }

  void _initWindows(List<ScheduleWindowModel> existingWindows) {
    _windowsMap = {};
    for (final day in _dayOrder) {
      _windowsMap[day] = ScheduleWindowModel(
        dayOfWeek: day,
        startTime: '07:00',
        endTime: '22:00',
        isEnabled: true,
      );
    }

    for (final window in existingWindows) {
      _windowsMap[window.dayOfWeek] = window;
    }
  }

  Future<void> _selectTime({required bool isStart}) async {
    final currentWindow = _windowsMap[_selectedDayOfWeek]!;
    final timeStr = isStart ? currentWindow.startTime : currentWindow.endTime;
    final parts = timeStr.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 7,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _windowsMap[_selectedDayOfWeek] =
              currentWindow.copyWith(startTime: formatted);
        } else {
          _windowsMap[_selectedDayOfWeek] =
              currentWindow.copyWith(endTime: formatted);
        }
      });
    }
  }

  void _applyToAllDays() {
    final currentWindow = _windowsMap[_selectedDayOfWeek]!;
    setState(() {
      for (final day in _dayOrder) {
        _windowsMap[day] = ScheduleWindowModel(
          dayOfWeek: day,
          startTime: currentWindow.startTime,
          endTime: currentWindow.endTime,
          isEnabled: currentWindow.isEnabled,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('monitoring_schedule_applied_all_days')),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static const List<int> _presetMinutes = [15, 30, 60, 120, 240, 480, 720, 1440];

  String _formatPresetChipLabel(int minutes) {
    switch (minutes) {
      case 15:
        return '15p';
      case 30:
        return '30p';
      case 60:
        return '1h';
      case 120:
        return '2h';
      case 240:
        return '4h';
      case 480:
        return '8h';
      case 720:
        return '12h';
      case 1440:
        return '24h';
      default:
        if (minutes >= 60 && minutes % 60 == 0) {
          return '${minutes ~/ 60}h';
        }
        return '${minutes}p';
    }
  }

  String _formatDurationText(int minutes) {
    if (minutes < 60) {
      return context.tr('common_minutes', args: {'minutes': minutes.toString()});
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) {
      return context.tr('common_hours', args: {'hours': h.toString()});
    }
    return context.tr('common_hours_minutes', args: {'hours': h.toString(), 'minutes': m.toString()});
  }

  String _formatThresholdPreview(int minutes) {
    if (minutes < 60) {
      return context.tr('common_minutes', args: {'minutes': minutes.toString()});
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final durationStr = m == 0
        ? context.tr('common_hours', args: {'hours': h.toString()})
        : context.tr('common_hours_minutes', args: {'hours': h.toString(), 'minutes': m.toString()});
    return '${context.tr('common_minutes', args: {'minutes': minutes.toString()})} ($durationStr)';
  }

  int _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  int get _activeMinutes {
    final currentWindow = _windowsMap[_selectedDayOfWeek]!;
    final start = _parseTimeToMinutes(currentWindow.wakeTime);
    final end = _parseTimeToMinutes(currentWindow.bedtime);
    if (end >= start) {
      return end - start;
    } else {
      return (24 * 60 - start) + end;
    }
  }

  int get _sleepMinutes => 24 * 60 - _activeMinutes;

  Future<void> _showCustomThresholdDialog() async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => CustomThresholdScreen(
          initialValue: _inactivityThreshold,
          formatPreview: _formatThresholdPreview,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _inactivityThreshold = result;
      });
    }
  }

  Future<void> _showCustomGracePeriodDialog() async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => CustomGracePeriodScreen(
          initialValue: _checkInGracePeriod,
          formatPreview: _formatDurationText,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _checkInGracePeriod = result;
        _isCustomGracePeriod = true;
      });
    }
  }

  Future<void> _openCheckInRemindersScreen() async {
    final updatedTimes = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => CheckInRemindersScreen(
          initialTimes: List<String>.from(_reminderTimes),
        ),
      ),
    );
    if (updatedTimes != null && mounted) {
      setState(() {
        _reminderTimes = updatedTimes;
      });
      final selfConfig = await LocalStorage.getSelfMonitoringConfig() ?? <String, dynamic>{};
      selfConfig['reminderTimes'] = _reminderTimes;
      await LocalStorage.saveSelfMonitoringConfig(selfConfig);
    }
  }

  Future<void> _saveConfig() async {
    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    try {
      final scheduleList = _dayOrder.map((d) => _windowsMap[d]!.toJson()).toList();

      if (widget.relationship == null) {
        final selfConfig = {
          'inactivityThresholdMinutes': _inactivityThreshold,
          'checkInGraceMinutes': _checkInGracePeriod,
          'checkInGracePeriodMinutes': _checkInGracePeriod,
          'locationEnabled': _locationEnabled,
          'timezone': _timezone,
          'reminderTimes': _reminderTimes,
          'pauseWhenTraveling': _pauseWhenTraveling,
          'lowBatteryAlert': _lowBatteryAlert,
          'scheduleWindows': scheduleList,
        };
        await LocalStorage.saveSelfMonitoringConfig(selfConfig);

        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('monitoring_config_update_success', fallback: 'Đã lưu cài đặt giám sát')),
              backgroundColor: AppColors.primary,
            ),
          );
          try {
            await Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData();
          } catch (_) {}
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
        return;
      }

      String? currentUserId;
      try {
        currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
      } catch (_) {}
      currentUserId ??= await LocalStorage.getUserId();
      final isMonitoredUser = widget.relationship!.monitoredUserId == currentUserId;

      final Map<String, dynamic> patchData = {
        'inactivityThresholdMinutes': _inactivityThreshold,
        'checkInGraceMinutes': _checkInGracePeriod,
        'timezone': _timezone,
        'scheduleWindows': scheduleList,
      };
      if (isMonitoredUser) {
        patchData['locationEnabled'] = _locationEnabled;
      }

      final response = await _apiClient.dio.patch(
        ApiEndpoints.monitoringConfig(widget.relationship!.id),
        data: patchData,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (response.statusCode == 200 || response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('monitoring_config_update_success')),
              backgroundColor: AppColors.primary,
            ),
          );
          try {
            await Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData();
          } catch (_) {}
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveErrorMessage = context.tr('monitoring_config_save_error');
        });
      }
    }
  }

  Widget _buildMiniTimeChip(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        time,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildAnimatedPillToggle({
    required bool value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF2E7D60) : const Color(0xFFD6DDD9),
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupRow({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (subtitleWidget != null)
                      subtitleWidget
                    else if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentWindow = _windowsMap[_selectedDayOfWeek]!;
    final isOvernight = currentWindow.isOvernight;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: AppBar(
        title: Text(
          context.tr('schedule_title'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF184A3E),
          ),
        ),
        actions: const [
          ActiveAccountAppBarAction(compact: true),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 56.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Target User Header (when configuring a specific relationship)
            if (widget.relationship != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      radius: 22,
                      child: Text(
                        (widget.relationship!.monitoredUser?.fullName ?? 'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.relationship!.monitoredUser?.fullName ??
                                context.tr('monitored_relative_default'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('monitoring_relationship_prefix', args: {
                              'relation': widget.relationship!.label ??
                                  context.tr('family_relation_default'),
                            }),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_saveErrorMessage != null) ...[
              CalmErrorCard(
                message: _saveErrorMessage!,
                onRetry: _saveConfig,
              ),
              const SizedBox(height: 12),
            ],

            // =================================================================
            // SECTION 1: UNIFIED SCHEDULE & QUIET HOURS CARD
            // (Eliminates the duplicate ActiveHoursScheduleScreen & overview card)
            // =================================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with Active Hours summary badge
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.wb_sunny_outlined,
                          color: AppColors.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                'monitoring_overview_active_hours',
                                fallback: 'Khung giờ hoạt động',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${currentWindow.startTime} - ${currentWindow.endTime} • ${context.tr('monitoring_overview_daily', fallback: 'Hằng ngày')}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF4A6B61),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Compact Quiet Hours Explanation Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.nightlight_round,
                              color: AppColors.primaryDark,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                context.tr('monitoring_quiet_hours_title'),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('monitoring_quiet_hours_desc'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.wb_sunny_rounded,
                              color: AppColors.primary,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                context.tr('monitoring_active_hours_desc'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 7-Day Selector Strip
                  Row(
                    children: _dayOrder.map((day) {
                      final isSelected = day == _selectedDayOfWeek;
                      final window = _windowsMap[day]!;
                      final isEnabled = window.isEnabled;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDayOfWeek = day),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isEnabled
                                        ? AppColors.primaryLight
                                        : const Color(0xFFF3F4F6)),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isEnabled
                                          ? AppColors.primaryLight
                                          : AppColors.divider),
                                ),
                              ),
                                child: Column(
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      window.dayNameShort,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : (isEnabled
                                                ? AppColors.primary
                                                : AppColors.textMuted),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.white
                                          : (isEnabled
                                              ? AppColors.primary
                                              : Colors.transparent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),

                  // Selected Day Toggle & Time Pickers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentWindow.dayNameFull,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentWindow.isEnabled
                                  ? context.tr('day_enabled')
                                  : context.tr('day_disabled'),
                              style: TextStyle(
                                fontSize: 12,
                                color: currentWindow.isEnabled
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: currentWindow.isEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _windowsMap[_selectedDayOfWeek] =
                                currentWindow.copyWith(isEnabled: val);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Opacity(
                    opacity: currentWindow.isEnabled ? 1.0 : 0.4,
                    child: IgnorePointer(
                      ignoring: !currentWindow.isEnabled,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimePickerTile(
                                  label:
                                      context.tr('monitoring_wake_time_label'),
                                  time: currentWindow.wakeTime,
                                  icon: Icons.wb_sunny_outlined,
                                  onTap: () => _selectTime(isStart: true),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.textMuted,
                                  size: 18,
                                ),
                              ),
                              Expanded(
                                child: _buildTimePickerTile(
                                  label: context.tr('monitoring_bedtime_label'),
                                  time: currentWindow.bedtime,
                                  icon: Icons.bedtime_outlined,
                                  onTap: () => _selectTime(isStart: false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr(
                                      'monitoring_sleep_active_summary',
                                      args: {
                                        'sleep': _formatDurationText(
                                          _sleepMinutes,
                                        ),
                                        'active': _formatDurationText(
                                          _activeMinutes,
                                        ),
                                        'bedtime': currentWindow.bedtime,
                                        'wakeTime': currentWindow.wakeTime,
                                      },
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (currentWindow.isEnabled && isOvernight) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.nightlight_round,
                            color: Color(0xFF6366F1),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('overnight_badge'),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3730A3),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr(
                                    'monitoring_overnight_schedule_summary',
                                    args: {
                                      'start': currentWindow.startTime,
                                      'startDay': currentWindow.dayNameFull,
                                      'end': currentWindow.endTime,
                                      'nextDay': currentWindow.nextDayNameFull,
                                    },
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF4338CA),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _applyToAllDays,
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: Text(
                        context.tr('apply_to_all_days'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primaryLight),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // =================================================================
            // SECTION 2: REMINDERS & QUICK MONITORING PREFERENCES
            // (Grouped cleanly into a single card instead of 3 separate cards)
            // =================================================================
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildGroupRow(
                    icon: Icons.notifications_active_outlined,
                    title: context.tr(
                      'monitoring_overview_check_reminders',
                      fallback: 'Nhắc nhở kiểm tra',
                    ),
                    onTap: _openCheckInRemindersScreen,
                    subtitleWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _reminderTimes.length == 3
                              ? context.tr(
                                  'monitoring_overview_three_per_day',
                                  fallback: '3 lần /ngày',
                                )
                              : '${_reminderTimes.length} ${context.tr('monitoring_overview_three_per_day', fallback: '3 lần /ngày').replaceFirst('3 ', '')}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF4A6B61),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _reminderTimes
                              .map((t) => _buildMiniTimeChip(t))
                              .toList(),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF8CA098),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: AppColors.divider,
                  ),
                  _buildGroupRow(
                    icon: Icons.pause_circle_outline_rounded,
                    title: context.tr(
                      'monitoring_overview_pause_mode',
                      fallback: 'Chế độ tạm dừng',
                    ),
                    subtitle: context.tr(
                      'monitoring_overview_pause_travel',
                      fallback: 'Tạm dừng khi nghỉ du lịch',
                    ),
                    trailing: _buildAnimatedPillToggle(
                      value: _pauseWhenTraveling,
                      onTap: () => setState(
                        () => _pauseWhenTraveling = !_pauseWhenTraveling,
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: AppColors.divider,
                  ),
                  _buildGroupRow(
                    icon: Icons.battery_alert_rounded,
                    title: context.tr(
                      'monitoring_overview_low_battery_title',
                      fallback: 'Thông báo pin yếu',
                    ),
                    subtitle: context.tr(
                      'monitoring_overview_low_battery_sub',
                      fallback: 'Khi pin < 20%',
                    ),
                    trailing: _buildAnimatedPillToggle(
                      value: _lowBatteryAlert,
                      onTap: () =>
                          setState(() => _lowBatteryAlert = !_lowBatteryAlert),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: AppColors.divider,
                  ),
                  _buildGroupRow(
                    icon: Icons.location_on_outlined,
                    title: context.tr('monitoring_share_location_title'),
                    subtitle: context.tr('monitoring_share_location_desc'),
                    trailing: _buildAnimatedPillToggle(
                      value: _locationEnabled,
                      onTap: () =>
                          setState(() => _locationEnabled = !_locationEnabled),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // =================================================================
            // SECTION 3: INACTIVITY THRESHOLD & GRACE PERIOD
            // =================================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          context.tr('monitoring_inactivity_threshold_title'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatThresholdPreview(_inactivityThreshold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('monitoring_inactivity_threshold_desc'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._presetMinutes.map((preset) {
                        final isSelected = _inactivityThreshold == preset;
                        return ChoiceChip(
                          label: Text(_formatPresetChipLabel(preset)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                          backgroundColor: const Color(0xFFF3F4F6),
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.cardBorder,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _inactivityThreshold = preset);
                            }
                          },
                        );
                      }),
                      Builder(
                        builder: (context) {
                          final isCustom =
                              !_presetMinutes.contains(_inactivityThreshold);
                          return ChoiceChip(
                            label: Text(
                              isCustom
                                  ? context.tr(
                                      'monitoring_custom_chip',
                                      args: {
                                        'duration': _formatPresetChipLabel(
                                          _inactivityThreshold,
                                        ),
                                      },
                                    )
                                  : context.tr('monitoring_custom_dots'),
                            ),
                            selected: isCustom,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isCustom ? Colors.white : AppColors.primary,
                              fontWeight: isCustom
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                            backgroundColor: AppColors.primaryLight,
                            shape: const StadiumBorder(),
                            side: const BorderSide(
                              color: AppColors.primaryLight,
                            ),
                            onSelected: (_) => _showCustomThresholdDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Check-in Grace Period Setting
                  Text(
                    context.tr('monitoring_grace_period_title'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('monitoring_grace_period_desc'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    // ignore: deprecated_member_use
                    value: _checkInGracePeriod,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.cardBorder),
                      ),
                      prefixIcon: const Icon(
                        Icons.timer_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 15,
                        child: Text(
                          context.tr('monitoring_minutes_15'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 30,
                        child: Text(
                          context.tr('monitoring_minutes_30_recommended'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 45,
                        child: Text(
                          context.tr('monitoring_minutes_45'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 60,
                        child: Text(
                          context.tr('monitoring_minutes_60'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isCustomGracePeriod)
                        DropdownMenuItem(
                          value: _checkInGracePeriod,
                          child: Text(
                            context.tr(
                              'monitoring_custom_grace_selected',
                              args: {'minutes': '$_checkInGracePeriod'},
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _checkInGracePeriod = val;
                          _isCustomGracePeriod = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _showCustomGracePeriodDialog,
                      icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                      label: Text(
                        _isCustomGracePeriod
                            ? context.tr(
                                'monitoring_custom_grace_current',
                                args: {'minutes': '$_checkInGracePeriod'},
                              )
                            : context.tr('monitoring_custom_time_other'),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      context.tr('common_save', fallback: 'Lưu cài đặt'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required String time,
    IconData icon = Icons.access_time_rounded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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
}

class _CustomMinutesInputScaffold extends StatefulWidget {
  final int initialValue;
  final String Function(int) formatPreview;
  final String titleKey;
  final String descKey;
  final String labelKey;
  final String rangeErrorKey;

  const _CustomMinutesInputScaffold({
    required this.initialValue,
    required this.formatPreview,
    required this.titleKey,
    required this.descKey,
    required this.labelKey,
    required this.rangeErrorKey,
  });

  @override
  State<_CustomMinutesInputScaffold> createState() =>
      _CustomMinutesInputScaffoldState();
}

class _CustomMinutesInputScaffoldState
    extends State<_CustomMinutesInputScaffold> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsedVal = int.tryParse(_controller.text.trim());
    final preview = parsedVal != null && parsedVal > 0
        ? widget.formatPreview(parsedVal)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFAF8),
        elevation: 0,
        title: Text(
          context.tr(widget.titleKey),
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr(widget.descKey),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.inputFill,
                    labelText: context.tr(widget.labelKey),
                    suffixText: context.tr('common_minutes_unit'),
                    errorText: _errorText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _errorText = null;
                    });
                  },
                ),
                if (preview != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.tr(
                        'monitoring_custom_preview',
                        args: {'preview': preview},
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(context.tr('common_cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final val = int.tryParse(_controller.text.trim());
                          if (val == null) {
                            setState(() {
                              _errorText =
                                  context.tr('monitoring_custom_error_invalid');
                            });
                            return;
                          }
                          if (val < 1 || val > 1440) {
                            setState(() {
                              _errorText = context.tr(widget.rangeErrorKey);
                            });
                            return;
                          }
                          Navigator.of(context).pop(val);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: Text(context.tr('common_apply')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomThresholdScreen extends StatelessWidget {
  final int initialValue;
  final String Function(int) formatPreview;

  const CustomThresholdScreen({
    super.key,
    required this.initialValue,
    required this.formatPreview,
  });

  @override
  Widget build(BuildContext context) {
    return _CustomMinutesInputScaffold(
      initialValue: initialValue,
      formatPreview: formatPreview,
      titleKey: 'monitoring_custom_inactivity_title',
      descKey: 'monitoring_custom_inactivity_desc',
      labelKey: 'monitoring_custom_minutes_label',
      rangeErrorKey: 'monitoring_custom_error_range_inactivity',
    );
  }
}

class CustomGracePeriodScreen extends StatelessWidget {
  final int initialValue;
  final String Function(int) formatPreview;

  const CustomGracePeriodScreen({
    super.key,
    required this.initialValue,
    required this.formatPreview,
  });

  @override
  Widget build(BuildContext context) {
    return _CustomMinutesInputScaffold(
      initialValue: initialValue,
      formatPreview: formatPreview,
      titleKey: 'monitoring_custom_grace_title',
      descKey: 'monitoring_custom_grace_desc',
      labelKey: 'monitoring_custom_grace_label',
      rangeErrorKey: 'monitoring_custom_error_range_grace',
    );
  }
}

class CheckInRemindersScreen extends StatefulWidget {
  final List<String> initialTimes;

  const CheckInRemindersScreen({
    super.key,
    required this.initialTimes,
  });

  @override
  State<CheckInRemindersScreen> createState() => _CheckInRemindersScreenState();
}

class _CheckInRemindersScreenState extends State<CheckInRemindersScreen> {
  late List<String> _times;

  @override
  void initState() {
    super.initState();
    _times = List<String>.from(widget.initialTimes);
    if (_times.isEmpty) {
      _times = ['09:00', '15:00', '20:00'];
    }
  }

  Future<void> _editOrAddTime({int? index}) async {
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    if (index != null && index < _times.length) {
      final parts = _times[index].split(':');
      initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (index != null) {
          _times[index] = formatted;
        } else if (!_times.contains(formatted)) {
          _times.add(formatted);
        }
        _times.sort();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFAF8),
        elevation: 0,
        title: Text(
          context.tr(
            'monitoring_overview_check_reminders',
            fallback: 'Nhắc nhở kiểm tra',
          ),
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr(
                          'notif_reminders_toggle',
                          fallback:
                              'Chọn các mốc giờ trong ngày để ứng dụng nhắc xác nhận an toàn.',
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text(
                      context.tr(
                        'monitoring_reminder_preset_2',
                        fallback: '2 lần (08:00, 20:00)',
                      ),
                    ),
                    onPressed: () {
                      setState(() => _times = ['08:00', '20:00']);
                    },
                  ),
                  ActionChip(
                    label: Text(
                      context.tr(
                        'monitoring_reminder_preset_3',
                        fallback: '3 lần (09:00, 15:00, 20:00)',
                      ),
                    ),
                    onPressed: () {
                      setState(() => _times = ['09:00', '15:00', '20:00']);
                    },
                  ),
                  ActionChip(
                    label: Text(
                      context.tr(
                        'monitoring_reminder_preset_4',
                        fallback: '4 lần (08:00, 12:00, 16:00, 20:00)',
                      ),
                    ),
                    onPressed: () {
                      setState(
                        () => _times = ['08:00', '12:00', '16:00', '20:00'],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _times.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppColors.divider,
                        ),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.alarm_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          _times[i],
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        onTap: () => _editOrAddTime(index: i),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              onPressed: () => _editOrAddTime(index: i),
                            ),
                            if (_times.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() => _times.removeAt(i));
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _editOrAddTime(),
                icon: const Icon(Icons.add_alarm_rounded, size: 18),
                label: Text(
                  context.tr(
                    'monitoring_custom_time_other',
                    fallback: 'Thêm mốc giờ nhắc nhở',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_times),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: Text(
                  context.tr('common_apply', fallback: 'Áp dụng'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


