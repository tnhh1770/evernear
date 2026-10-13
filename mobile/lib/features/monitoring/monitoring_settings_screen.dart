import 'package:flutter/material.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/relationship_model.dart';
import '../../core/models/schedule_window_model.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/calm_error_card.dart';

class MonitoringSettingsScreen extends StatefulWidget {
  final RelationshipModel relationship;

  const MonitoringSettingsScreen({super.key, required this.relationship});

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
  int _selectedDayOfWeek = 1; // Default to Monday (T2)
  bool _isSaving = false;
  String? _saveErrorMessage;
  bool _isCustomGracePeriod = false;

  // Weekday ordering for Vietnam: Monday (1) to Sunday (0)
  static const List<int> _dayOrder = [1, 2, 3, 4, 5, 6, 0];

  @override
  void initState() {
    super.initState();
    final config = widget.relationship.config;
    _inactivityThreshold = config?.inactivityThresholdMinutes ?? 180;
    _checkInGracePeriod = config?.checkInGracePeriodMinutes ?? 30;
    _locationEnabled = config?.locationEnabled ?? true;
    _timezone = config?.timezone ?? 'Asia/Ho_Chi_Minh';

    _initWindows(config?.scheduleWindows ?? []);
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
    final controller = TextEditingController(text: _inactivityThreshold.toString());
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final parsedVal = int.tryParse(controller.text.trim());
            final preview = parsedVal != null && parsedVal > 0
                ? _formatThresholdPreview(parsedVal)
                : null;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(context.tr('monitoring_custom_inactivity_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('monitoring_custom_inactivity_desc'),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: context.tr('monitoring_custom_minutes_label'),
                        suffixText: context.tr('common_minutes_unit'),
                        errorText: errorText,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      onChanged: (_) {
                        setDialogState(() {
                          errorText = null;
                        });
                      },
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.tr('monitoring_custom_preview', args: {'preview': preview}),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(context.tr('common_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final val = int.tryParse(controller.text.trim());
                    if (val == null) {
                      setDialogState(() {
                        errorText = context.tr('monitoring_custom_error_invalid');
                      });
                      return;
                    }
                    if (val < 15 || val > 1440) {
                      setDialogState(() {
                        errorText = context.tr('monitoring_custom_error_range_inactivity');
                      });
                      return;
                    }
                    setState(() {
                      _inactivityThreshold = val;
                    });
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(context.tr('common_apply')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCustomGracePeriodDialog() async {
    final controller = TextEditingController(text: _checkInGracePeriod.toString());
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final parsedVal = int.tryParse(controller.text.trim());
            final preview = parsedVal != null && parsedVal > 0
                ? _formatDurationText(parsedVal)
                : null;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.hourglass_bottom_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.tr('monitoring_custom_grace_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('monitoring_custom_grace_desc'),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: context.tr('monitoring_custom_grace_label'),
                        suffixText: context.tr('common_minutes_unit'),
                        errorText: errorText,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      onChanged: (_) {
                        setDialogState(() {
                          errorText = null;
                        });
                      },
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.tr('monitoring_custom_preview', args: {'preview': preview}),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(context.tr('common_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final val = int.tryParse(controller.text.trim());
                    if (val == null) {
                      setDialogState(() {
                        errorText = context.tr('monitoring_custom_error_invalid');
                      });
                      return;
                    }
                    if (val < 1 || val > 1440) {
                      setDialogState(() {
                        errorText = context.tr('monitoring_custom_error_range_grace');
                      });
                      return;
                    }
                    setState(() {
                      _checkInGracePeriod = val;
                      _isCustomGracePeriod = true;
                    });
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(context.tr('common_apply')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveConfig() async {
    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    try {
      final scheduleList = _dayOrder.map((d) => _windowsMap[d]!.toJson()).toList();

      final response = await _apiClient.dio.patch(
        ApiEndpoints.monitoringConfig(widget.relationship.id),
        data: {
          'inactivityThresholdMinutes': _inactivityThreshold,
          'checkInGraceMinutes': _checkInGracePeriod,
          'locationEnabled': _locationEnabled,
          'timezone': _timezone,
          'scheduleWindows': scheduleList,
        },
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
          Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final currentWindow = _windowsMap[_selectedDayOfWeek]!;
    final isOvernight = currentWindow.isOvernight;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('schedule_title', fallback: AppStrings.scheduleTitle)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.secondaryLight,
                    radius: 24,
                    child: Text(
                      (widget.relationship.monitoredUser?.fullName ?? 'U')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.relationship.monitoredUser?.fullName ??
                              context.tr('monitored_relative_default'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('monitoring_relationship_prefix', args: {
                            'relation': widget.relationship.label ??
                                context.tr('family_relation_default'),
                          }),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_saveErrorMessage != null) ...[
              CalmErrorCard(
                message: _saveErrorMessage!,
                onRetry: _saveConfig,
              ),
              const SizedBox(height: 12),
            ],

            // Schedule Section Header
            Text(
              context.tr('monitoring_schedule_and_sleep_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('schedule_subtitle', fallback: AppStrings.scheduleSubtitle),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            // Quiet Hours & Sleep Explanation Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF), // soft indigo
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.nightlight_round, color: Color(0xFF4F46E5), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('monitoring_quiet_hours_title'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3730A3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('monitoring_quiet_hours_desc'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4338CA),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_rounded, color: Color(0xFFD97706), size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.tr('monitoring_active_hours_desc'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade900,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Day Selector Strip
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: _dayOrder.map((day) {
                  final isSelected = day == _selectedDayOfWeek;
                  final window = _windowsMap[day]!;
                  final isEnabled = window.isEnabled;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDayOfWeek = day),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isEnabled ? AppColors.primaryLight : const Color(0xFFF3F4F6)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isEnabled ? AppColors.primaryLight : AppColors.divider),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                window.dayNameShort,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : (isEnabled ? AppColors.primary : AppColors.textMuted),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white
                                      : (isEnabled ? AppColors.primary : Colors.transparent),
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
            ),
            const SizedBox(height: 16),

            // Active Day Editor Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentWindow.dayNameFull,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
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
                  Text(
                    currentWindow.isEnabled
                        ? context.tr('day_enabled', fallback: AppStrings.dayEnabled)
                        : context.tr('day_disabled', fallback: AppStrings.dayDisabled),
                    style: TextStyle(
                      fontSize: 12,
                      color: currentWindow.isEnabled
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                  const Divider(height: 24),

                  // Start and End Time Pickers (Framed as Wake Time and Bedtime)
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
                                  label: context.tr('monitoring_wake_time_label'),
                                  time: currentWindow.wakeTime,
                                  icon: Icons.wb_sunny_outlined,
                                  onTap: () => _selectTime(isStart: true),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(Icons.arrow_forward_rounded,
                                    color: AppColors.textMuted, size: 20),
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
                          const SizedBox(height: 12),
                          // Sleep & Monitoring Summary Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 15, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr('monitoring_sleep_active_summary', args: {
                                      'sleep': _formatDurationText(_sleepMinutes),
                                      'active': _formatDurationText(_activeMinutes),
                                      'bedtime': currentWindow.bedtime,
                                      'wakeTime': currentWindow.wakeTime,
                                    }),
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

                  // Overnight Window Banner
                  if (currentWindow.isEnabled && isOvernight) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF), // Soft indigo
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.nightlight_round,
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('overnight_badge', fallback: AppStrings.overnightBadge),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3730A3),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('monitoring_overnight_schedule_summary', args: {
                                    'start': currentWindow.startTime,
                                    'startDay': currentWindow.dayNameFull,
                                    'end': currentWindow.endTime,
                                    'nextDay': currentWindow.nextDayNameFull,
                                  }),
                                  style: const TextStyle(
                                    fontSize: 12,
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

                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _applyToAllDays,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(context.tr('apply_to_all_days', fallback: AppStrings.applyToAllDays)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primaryLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Inactivity Threshold Setting (Preset Chips + Custom Input)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('monitoring_inactivity_threshold_title'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _formatThresholdPreview(_inactivityThreshold),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('monitoring_inactivity_threshold_desc'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          backgroundColor: const Color(0xFFF3F4F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.divider,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _inactivityThreshold = preset);
                            }
                          },
                        );
                      }),
                      // Custom chip (auto-selected when non-standard value from backend or user)
                      Builder(
                        builder: (context) {
                          final isCustom = !_presetMinutes.contains(_inactivityThreshold);
                          return ChoiceChip(
                            label: Text(
                              isCustom
                                  ? context.tr('monitoring_custom_chip', args: {'duration': _formatPresetChipLabel(_inactivityThreshold)})
                                  : context.tr('monitoring_custom_dots'),
                            ),
                            selected: isCustom,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isCustom ? Colors.white : AppColors.primary,
                              fontWeight: isCustom ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13,
                            ),
                            backgroundColor: AppColors.primaryLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.primaryLight),
                            ),
                            onSelected: (_) => _showCustomThresholdDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Check-in Grace Period Setting (Chips + Custom Option)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('monitoring_grace_period_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('monitoring_grace_period_desc'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _checkInGracePeriod,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    items: [
                      DropdownMenuItem(value: 15, child: Text(context.tr('monitoring_minutes_15'))),
                      DropdownMenuItem(value: 30, child: Text(context.tr('monitoring_minutes_30_recommended'))),
                      DropdownMenuItem(value: 45, child: Text(context.tr('monitoring_minutes_45'))),
                      DropdownMenuItem(value: 60, child: Text(context.tr('monitoring_minutes_60'))),
                      if (_isCustomGracePeriod)
                        DropdownMenuItem(
                          value: _checkInGracePeriod,
                          child: Text(context.tr('monitoring_custom_grace_selected', args: {'minutes': '$_checkInGracePeriod'})),
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _showCustomGracePeriodDialog,
                      icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                      label: Text(_isCustomGracePeriod
                          ? context.tr('monitoring_custom_grace_current', args: {'minutes': '$_checkInGracePeriod'})
                          : context.tr('monitoring_custom_time_other')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Location Sharing Toggle
            Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    context.tr('monitoring_share_location_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    context.tr('monitoring_share_location_desc'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  value: _locationEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setState(() => _locationEnabled = val),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
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
                const SizedBox(width: 8),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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
