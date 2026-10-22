import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/fcm_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _emergencyAlerts = true;
  bool _checkInReminders = true;
  bool _systemUpdates = false;
  String _selectedRingtone = 'Nhạc chuông';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pushNotifications = prefs.getBool('notif_push') ?? true;
      _emergencyAlerts = prefs.getBool('notif_emergency') ?? true;
      _checkInReminders = prefs.getBool('notif_reminders') ?? true;
      _systemUpdates = prefs.getBool('notif_system') ?? false;
      _selectedRingtone = prefs.getString('notif_ringtone') ?? 'Nhạc chuông';
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  String _localizedRingtoneLabel(BuildContext context, String raw) {
    switch (raw) {
      case 'Nhạc chuông':
        return context.tr('notif_sound_default', fallback: 'Nhạc chuông');
      case 'Chuông nhẹ nhàng':
        return context.tr('notif_sound_gentle', fallback: 'Chuông nhẹ nhàng');
      case 'Chuông khẩn cấp':
        return context.tr('notif_sound_urgent', fallback: 'Chuông khẩn cấp');
      case 'Chỉ rung':
        return context.tr('notif_sound_vibrate', fallback: 'Chỉ rung');
      default:
        return raw;
    }
  }

  void _showSoundPicker() {
    final options = [
      'Nhạc chuông',
      'Chuông nhẹ nhàng',
      'Chuông khẩn cấp',
      'Chỉ rung',
    ];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: Text(
              ctx.tr('notif_sound_modal_title', fallback: 'Âm thanh thông báo'),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          body: SafeArea(
            minimum: const EdgeInsets.only(bottom: 24),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < options.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: AppColors.divider,
                          ),
                        ListTile(
                          title: Text(
                            _localizedRingtoneLabel(ctx, options[i]),
                            style: TextStyle(
                              fontWeight: options[i] == _selectedRingtone
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: options[i] == _selectedRingtone
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          trailing: options[i] == _selectedRingtone
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () async {
                            final opt = options[i];
                            setState(() => _selectedRingtone = opt);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('notif_ringtone', opt);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendTestPushNotification() async {
    final title = context.tr('app_name', fallback: 'Evenear');
    final body = context.tr(
      'notif_test_push_sent',
      fallback: 'Đã gửi thông báo đẩy thử nghiệm thành công!',
    );
    await FcmService().sendTestNotification(title: title, body: body);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.tr('notif_settings_title', fallback: 'Thông báo'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: context.tr(
              'notif_customize_tooltip',
              fallback: 'Tùy chỉnh thông báo',
            ),
            constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
            onPressed: _showSoundPicker,
            icon: const Icon(
              Icons.tune_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 52),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                _buildToggleRow(
                  icon: Icons.notifications_active_outlined,
                  title: context.tr(
                    'notif_push_toggle',
                    fallback: 'Thông báo đẩy',
                  ),
                  value: _pushNotifications,
                  showDivider: true,
                  onChanged: (v) {
                    setState(() => _pushNotifications = v);
                    _savePref('notif_push', v);
                  },
                ),
                _buildToggleRow(
                  icon: Icons.warning_amber_rounded,
                  title: context.tr(
                    'notif_emergency_toggle',
                    fallback: 'Cảnh báo khẩn cấp',
                  ),
                  value: _emergencyAlerts,
                  showDivider: true,
                  onChanged: (v) {
                    setState(() => _emergencyAlerts = v);
                    _savePref('notif_emergency', v);
                  },
                ),
                _buildToggleRow(
                  icon: Icons.alarm_rounded,
                  title: context.tr(
                    'notif_reminders_toggle',
                    fallback: 'Nhắc nhở kiểm tra',
                  ),
                  value: _checkInReminders,
                  showDivider: true,
                  onChanged: (v) {
                    setState(() => _checkInReminders = v);
                    _savePref('notif_reminders', v);
                  },
                ),
                _buildToggleRow(
                  icon: Icons.system_update_alt_rounded,
                  title: context.tr(
                    'notif_system_updates_toggle',
                    fallback: 'Cập nhật từ hệ thống',
                  ),
                  value: _systemUpdates,
                  showDivider: false,
                  onChanged: (v) {
                    setState(() => _systemUpdates = v);
                    _savePref('notif_system', v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              context.tr('notif_sound_section', fallback: 'Âm thanh'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: InkWell(
              onTap: _showSoundPicker,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.music_note_outlined,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _localizedRingtoneLabel(context, _selectedRingtone),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(
                          'notif_push_status_active',
                          fallback: 'Dịch vụ thông báo đẩy đang hoạt động',
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('test_push_notification_button'),
                  onPressed: _pushNotifications ? _sendTestPushNotification : null,
                  icon: const Icon(Icons.notifications_active_rounded, size: 18),
                  label: Text(
                    context.tr(
                      'notif_test_push_button',
                      fallback: 'Kiểm tra thông báo đẩy',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.primary),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required bool value,
    bool showDivider = true,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: value,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 54, endIndent: 18, color: Color(0xFFEEF1EE)),
      ],
    );
  }
}
