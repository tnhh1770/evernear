import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/relationship_model.dart';
import '../../core/services/fcm_service.dart';
import '../../core/widgets/evenear_illustrations.dart';
import '../monitoring/monitoring_settings_screen.dart';

class RelativeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> relativeData;
  final RelationshipModel? relationship;

  const RelativeDetailScreen({
    super.key,
    required this.relativeData,
    this.relationship,
  });

  @override
  State<RelativeDetailScreen> createState() => _RelativeDetailScreenState();
}

class _RelativeDetailScreenState extends State<RelativeDetailScreen> {
  int _selectedSubTab = 0; // 0: Thông tin, 1: Hoạt động, 2: Thiết bị

  @override
  Widget build(BuildContext context) {
    final name = widget.relativeData['name']?.toString() ??
        widget.relationship?.monitoredUser?.fullName ??
        context.tr('monitored_relative_default', fallback: 'Người thân');
    final statusText = widget.relativeData['statusText']?.toString() ??
        (widget.relationship != null
            ? context.tr(
                'monitored_status_protected_pill',
                fallback: 'Đang được bảo vệ',
              )
            : context.tr(
                'relative_detail_not_connected',
                fallback: 'Chưa kết nối',
              ));
    final isAlert = widget.relativeData['isAlert'] == true;
    final lastConfirmed = widget.relativeData['lastConfirmed']?.toString() ??
        (widget.relationship?.config?.lastActivityAt != null
            ? DateFormat('dd/MM/yyyy • HH:mm')
                .format(widget.relationship!.config!.lastActivityAt!.toLocal())
            : context.tr(
                'guardian_no_activity_yet',
                fallback: 'Chưa có hoạt động',
              ));
    final location = widget.relativeData['location']?.toString() ??
        (widget.relationship?.config?.locationEnabled == true
            ? context.tr(
                'guardian_location_when_needed',
                fallback: 'Vị trí (chỉ khi cần)',
              )
            : context.tr(
                'guardian_no_location_shared',
                fallback: 'Không chia sẻ vị trí',
              ));
    final device = widget.relativeData['device']?.toString() ??
        (widget.relationship?.monitoredUser?.fullName != null
            ? context.tr(
                'guardian_relative_device',
                fallback: 'Thiết bị người thân',
              )
            : context.tr(
                'guardian_primary_device',
                fallback: 'Thiết bị chính',
              ));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.tr(
            'relative_detail_title',
            fallback: 'Chi tiết người thân',
          ),
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
              'schedule_title',
              fallback: 'Cài đặt giám sát',
            ),
            constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MonitoringSettingsScreen(
                    relationship: widget.relationship,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 52),
          children: [
          // Profile Card matching Screen 15 (15_guardian_person_detail.png)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCEEE4),
                    shape: BoxShape.circle,
                  ),
                  child: EvenearAvatar(
                    name: name,
                    radius: 36,
                    showStatusDot: false,
                    statusColor: isAlert
                        ? AppColors.stateCheckInRequired
                        : AppColors.stateActive,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isAlert
                              ? AppColors.stateCheckInRequired
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ContactRelativeScreen(
                                  name: name,
                                  statusText: statusText,
                                  isAlert: isAlert,
                                  lastConfirmed: lastConfirmed,
                                  location: location,
                                  phone: widget.relativeData['phone']?.toString() ??
                                      widget.relationship?.monitoredUser?.phone ??
                                      '',
                                  email: widget.relativeData['email']?.toString() ??
                                      widget.relationship?.monitoredUser?.email ??
                                      '',
                                  relationship: widget.relationship,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 17),
                          label: Text(
                            context.tr(
                              'relative_detail_contact_btn',
                              fallback: 'Liên hệ',
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Underline Sub-tabs matching 15_guardian_person_detail.png: Thông tin | Hoạt động | Thiết bị
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.cardBorder, width: 1.2),
              ),
            ),
            child: Row(
              children: [
                _buildSubTab(
                  0,
                  context.tr('relative_detail_tab_info', fallback: 'Thông tin'),
                ),
                _buildSubTab(
                  1,
                  context.tr(
                    'relative_detail_tab_activity',
                    fallback: 'Hoạt động',
                  ),
                ),
                _buildSubTab(
                  2,
                  context.tr('relative_detail_tab_device', fallback: 'Thiết bị'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_selectedSubTab == 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  _buildTimelineInfoRow(
                    icon: Icons.verified_user_outlined,
                    title: context.tr(
                      'relative_detail_last_confirmed',
                      fallback: 'Lần xác nhận gần nhất',
                    ),
                    value: lastConfirmed,
                    showBottomLine: true,
                  ),
                  const Divider(height: 1, indent: 36, color: Color(0xFFEEF1EE)),
                  _buildTimelineInfoRow(
                    icon: Icons.location_on_outlined,
                    title: context.tr(
                      'relative_detail_last_location',
                      fallback: 'Vị trí gần nhất',
                    ),
                    value: location,
                    showBottomLine: true,
                  ),
                  const Divider(height: 1, indent: 36, color: Color(0xFFEEF1EE)),
                  _buildTimelineInfoRow(
                    icon: Icons.phone_iphone_rounded,
                    title: context.tr(
                      'relative_detail_tab_device',
                      fallback: 'Thiết bị',
                    ),
                    value: device,
                    showBottomLine: false,
                    showChevron: true,
                  ),
                ],
              ),
            )
          else if (_selectedSubTab == 1) ...[
            _buildInfoRow(
              icon: Icons.verified_user_outlined,
              title: context.tr(
                'relative_detail_confirmed_safe',
                args: {'name': name},
                fallback: '$name đã xác nhận an toàn',
              ),
              value: lastConfirmed,
            ),
          ] else ...[
            _buildInfoRow(
              icon: Icons.phone_iphone_rounded,
              title: device,
              value: context.tr(
                'relative_detail_device_status_value',
                fallback: 'Hoạt động  •  Pin --%',
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildSubTab(int index, String label) {
    final isSelected = _selectedSubTab == index;
    final useRichText = index == 2 && _selectedSubTab == 0;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: useRichText
              ? RichText(
                  text: TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                )
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTimelineInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required bool showBottomLine,
    bool showChevron = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (showChevron)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContactRelativeScreen extends StatefulWidget {
  final String name;
  final String statusText;
  final bool isAlert;
  final String lastConfirmed;
  final String location;
  final String phone;
  final String email;
  final RelationshipModel? relationship;

  const ContactRelativeScreen({
    super.key,
    required this.name,
    required this.statusText,
    this.isAlert = false,
    required this.lastConfirmed,
    required this.location,
    required this.phone,
    this.email = '',
    this.relationship,
  });

  @override
  State<ContactRelativeScreen> createState() => _ContactRelativeScreenState();
}

class _ContactRelativeScreenState extends State<ContactRelativeScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _statusFeedback;
  bool _pingSent = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleCall() async {
    final hasPhone = widget.phone.trim().isNotEmpty;
    if (!hasPhone) {
      if (!mounted) return;
      final noPhoneMsg = context.tr(
        'account_not_updated',
        fallback: 'Người thân chưa cập nhật số điện thoại khẩn cấp.',
      );
      setState(() => _statusFeedback = noPhoneMsg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(noPhoneMsg),
          backgroundColor: AppColors.textPrimary,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: widget.phone));
    if (!mounted) return;
    final msg = context.tr(
      'relative_detail_contacting',
      args: {'name': '${widget.name} (${widget.phone})'},
      fallback: 'Đang kết nối cuộc gọi tới ${widget.name} (${widget.phone})...',
    );
    setState(() {
      _statusFeedback = msg;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _handleSendPing() async {
    final title = context.tr('app_name', fallback: 'Evenear');
    final body = context.tr(
      'monitoring_overview_check_reminders',
      fallback: 'Nhắc nhở kiểm tra an toàn',
    );
    await FcmService().sendTestNotification(
      title: '$title • ${widget.name}',
      body: body,
    );
    if (!mounted) return;
    setState(() {
      _pingSent = true;
      _statusFeedback =
          'Đã gửi tín hiệu nhắc xác nhận an toàn tới thiết bị của ${widget.name}.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_statusFeedback!),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _handleSendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: clean));
    if (!mounted) return;
    _messageController.clear();
    setState(() {
      _statusFeedback = 'Đã gửi tin nhắn tới ${widget.name}: "$clean"';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_statusFeedback!),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = widget.phone.trim().isNotEmpty;
    final displayPhone = hasPhone
        ? widget.phone.trim()
        : context.tr('account_not_updated', fallback: 'Chưa cập nhật');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          context.tr('relative_detail_contact_btn', fallback: 'Liên hệ người thân'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 24),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 52),
          children: [
            // Relative Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  EvenearAvatar(
                    name: widget.name,
                    radius: 32,
                    showStatusDot: true,
                    statusColor: widget.isAlert
                        ? AppColors.stateCheckInRequired
                        : AppColors.stateActive,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.statusText,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: widget.isAlert
                                ? AppColors.stateCheckInRequired
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.tr('relative_detail_last_confirmed', fallback: 'Lần xác nhận gần nhất')}: ${widget.lastConfirmed}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_statusFeedback != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusFeedback!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Contact Info & Location Details Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('account_phone_label', fallback: 'Số điện thoại khẩn cấp'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayPhone,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: hasPhone
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasPhone)
                        IconButton(
                          tooltip: context.tr(
                            'relative_detail_copy_phone_tooltip',
                            fallback: 'Sao chép số điện thoại',
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: widget.phone));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr(
                                    'relative_detail_phone_copied',
                                    args: {'phone': widget.phone},
                                    fallback: 'Đã sao chép số điện thoại: ${widget.phone}',
                                  ),
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  if (widget.email.isNotEmpty) ...[
                    const Divider(height: 24, color: AppColors.divider),
                    Row(
                      children: [
                        const Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Email',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.email,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 24, color: AppColors.divider),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('relative_detail_last_location', fallback: 'Vị trí gần nhất'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.location,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action 1: Direct Call Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: hasPhone ? _handleCall : null,
                icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                label: Text(
                  hasPhone
                      ? '${context.tr('incident_call_now_btn', fallback: 'Gọi ngay')} ($displayPhone)'
                      : context.tr('incident_call_now_btn', fallback: 'Gọi ngay'),
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Action 2: Send Safety Check-in Reminder Ping
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _handleSendPing,
                icon: Icon(
                  _pingSent
                      ? Icons.check_circle_rounded
                      : Icons.notifications_active_outlined,
                  size: 20,
                ),
                label: Text(
                  _pingSent
                      ? 'Đã gửi nhắc xác nhận an toàn'
                      : 'Gửi tín hiệu nhắc xác nhận an toàn',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action 3: Quick Check-in Message Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Gửi lời nhắn hỏi thăm nhanh',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: Text(
                          context.tr(
                            'relative_detail_msg_are_you_ok',
                            fallback: 'Bạn có ổn không?',
                          ),
                        ),
                        onPressed: () => _handleSendMessage(
                          'Chào ${widget.name}, bạn có ổn không? Nhấn xác nhận an toàn trên ứng dụng nhé!',
                        ),
                      ),
                      ActionChip(
                        label: Text(
                          context.tr(
                            'relative_detail_msg_confirm_safe',
                            fallback: 'Nhớ xác nhận an toàn nhé',
                          ),
                        ),
                        onPressed: () => _handleSendMessage(
                          'Nhớ bấm nút "Tôi vẫn ổn" trên ứng dụng Evenear giúp gia đình yên tâm nhé!',
                        ),
                      ),
                      ActionChip(
                        label: Text(
                          context.tr(
                            'relative_detail_msg_call_back',
                            fallback: 'Gọi lại cho mình nhé',
                          ),
                        ),
                        onPressed: () => _handleSendMessage(
                          'Khi nào xem tin nhắn nhớ gọi lại cho mình nhé!',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Nhập lời nhắn gửi tới ${widget.name}...',
                            filled: true,
                            fillColor: AppColors.inputFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.cardBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.cardBorder),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => _handleSendMessage(_messageController.text),
                        icon: const Icon(Icons.send_rounded, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

