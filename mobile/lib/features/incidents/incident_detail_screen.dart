import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/enums.dart';
import '../../core/models/incident_model.dart';
import '../../core/network/realtime_service.dart';
import 'incidents_provider.dart';

class IncidentDetailScreen extends StatefulWidget {
  final IncidentModel? incident;
  final String? incidentId;

  const IncidentDetailScreen({
    super.key,
    this.incident,
    this.incidentId,
  }) : assert(incident != null || incidentId != null, 'Either incident or incidentId must be provided');

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  IncidentModel? _incident;
  bool _isLoading = false;
  bool _isInitialFetching = false;
  String? _initialFetchError;
  StreamSubscription? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _incident = widget.incident;
    if (_incident != null) {
      _refreshDetail();
    } else if (widget.incidentId != null) {
      _isInitialFetching = true;
      _fetchInitialDetail(widget.incidentId!);
    }
    _realtimeSub = RealtimeService().eventStream.listen((event) {
      final type = event['type']?.toString();
      final incidentId = event['incidentId']?.toString();
      final currentId = _incident?.id ?? widget.incidentId;
      if (incidentId == currentId || type == 'CHECK_IN_CONFIRMED') {
        _refreshDetail();
      }
    });
  }

  Future<void> _fetchInitialDetail(String id) async {
    final provider = Provider.of<IncidentsProvider>(context, listen: false);
    final detail = await provider.getIncidentDetail(id);
    if (!mounted) return;
    setState(() {
      _isInitialFetching = false;
      if (detail != null) {
        _incident = detail;
      } else {
        _initialFetchError = 'Incident not found or unavailable';
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshDetail() async {
    final id = _incident?.id ?? widget.incidentId;
    if (id == null) return;
    final provider = Provider.of<IncidentsProvider>(context, listen: false);
    final detail = await provider.getIncidentDetail(id);
    if (detail != null && mounted) {
      setState(() => _incident = detail);
    }
  }

  String _getReasonLabel(IncidentReason reason, BuildContext context) {
    switch (reason) {
      case IncidentReason.MISSED_CHECK_IN:
        return context.tr('incident_missed_check_in', fallback: AppStrings.incidentMissedCheckIn);
      case IncidentReason.INACTIVITY:
      case IncidentReason.EXTENDED_INACTIVITY:
        return context.tr('incident_extended_inactivity', fallback: AppStrings.incidentExtendedInactivity);
      case IncidentReason.DEVICE_OFFLINE:
      case IncidentReason.CRITICAL_BATTERY_INACTIVITY:
        return context.tr('incident_device_offline', fallback: 'No activity confirmation received');
      case IncidentReason.MANUAL_SOS:
      case IncidentReason.MANUAL_TRIGGER:
        return context.tr('incident_sos', fallback: 'Emergency SOS confirmation');
    }
  }

  void _acknowledge() async {
    if (_incident == null) return;
    setState(() => _isLoading = true);
    final provider = Provider.of<IncidentsProvider>(context, listen: false);
    final ok = await provider.acknowledgeIncident(_incident!.id);
    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('incident_status_acknowledged', fallback: 'Acknowledged')),
            backgroundColor: AppColors.primary,
          ),
        );
        _refreshDetail();
      }
    }
  }

  void _showResolveDialog() {
    if (_incident == null) return;
    final noteController = TextEditingController();
    final provider = Provider.of<IncidentsProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('incident_resolve_dialog_title', fallback: 'Close Incident')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ctx.tr('incident_resolve_dialog_desc',
                    fallback: 'Confirmed contact and relative is safe. Would you like to add notes?'),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: ctx.tr('incident_resolve_dialog_hint', fallback: 'e.g. Called mom, she was gardening...'),
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
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              final ok = await provider.resolveIncident(
                _incident!.id,
                resolutionNote: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
              );
              if (mounted) {
                setState(() => _isLoading = false);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('incident_resolve_success', fallback: 'Incident successfully resolved.')),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                  Navigator.of(context).pop(); // Back to list
                }
              }
            },
            child: Text(ctx.tr('common_confirm', fallback: 'Confirm')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialFetching) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(context.tr('incident_detail_title', fallback: 'Incident Details')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_incident == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(context.tr('incident_detail_title', fallback: 'Incident Details')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  _initialFetchError ?? context.tr('common_error', fallback: 'Không tìm thấy sự cố'),
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.tr('common_back', fallback: 'Quay lại')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final incident = _incident!;
    final dateFormat = DateFormat('HH:mm:ss - dd/MM/yyyy');
    final isResolved = incident.status == IncidentStatus.RESOLVED;
    final isAcknowledged = incident.status == IncidentStatus.ACKNOWLEDGED;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('incident_detail_title', fallback: 'Incident Details')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status & Reason Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getReasonLabel(incident.reason, context),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('incident_triggered_at',
                        args: {'time': dateFormat.format(incident.triggeredAt.toLocal())},
                        fallback: 'Detected at: ${dateFormat.format(incident.triggeredAt.toLocal())}'),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('incident_risk_level',
                        args: {'score': '${incident.riskScore}'},
                        fallback: 'Risk Level: ${incident.riskScore}/100'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: incident.riskScore > 60
                          ? AppColors.stateGracePeriod
                          : AppColors.stateActive,
                    ),
                  ),
                  if (incident.resolutionNote != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      context.tr('incident_resolution_note',
                          args: {'note': incident.resolutionNote!},
                          fallback: 'Resolution note: ${incident.resolutionNote}'),
                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Audit Timeline
            Text(
              context.tr('incident_timeline_title', fallback: 'Incident Event Timeline'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            if (incident.events == null || incident.events!.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context.tr('incident_timeline_empty', fallback: 'Incident automatically triggered according to monitoring policy.'),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              )
            else
              ...List.generate(incident.events!.length, (index) {
                final ev = incident.events![index];
                final isLast = index == incident.events!.length - 1;
                return _buildEventTile(ev, context, isLast);
              }),
            const SizedBox(height: 24),

            // Actions for guardian
            if (!isResolved) ...[
              if (!isAcknowledged) ...[
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _acknowledge,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(context.tr('incident_acknowledge_button', fallback: AppStrings.acknowledgeButton)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.stateAcknowledged,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _showResolveDialog,
                icon: const Icon(Icons.done_all),
                label: Text(context.tr('incident_resolve_button', fallback: AppStrings.resolveButton)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(dynamic ev, BuildContext context, bool isLast) {
    String type = '';
    DateTime? timestamp;
    Map<String, dynamic> metadata = {};

    if (ev is Map) {
      type = (ev['type'] ?? ev['eventType'] ?? '').toString();
      final rawTs = ev['timestamp'] ?? ev['createdAt'];
      if (rawTs is DateTime) {
        timestamp = rawTs;
      } else if (rawTs != null) {
        timestamp = DateTime.tryParse(rawTs.toString());
      }
      if (ev['metadata'] is Map) {
        metadata = Map<String, dynamic>.from(ev['metadata'] as Map);
      }
    } else {
      type = ev.toString();
    }

    String title;
    IconData icon;
    Color color;

    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    switch (type.toUpperCase()) {
      case 'INCIDENT_CREATED':
        title = isVi ? 'Khởi tạo cảnh báo sự cố' : 'Incident Alert Created';
        icon = Icons.warning_amber_rounded;
        color = AppColors.stateCheckInRequired;
        break;
      case 'ESCALATION_TRIGGERED':
        title = isVi ? 'Leo thang cảnh báo tới người thân' : 'Alert Escalated to Relatives';
        icon = Icons.priority_high_rounded;
        color = AppColors.stateAlertTriggered;
        break;
      case 'MONITOR_ACKNOWLEDGED':
      case 'ACKNOWLEDGED':
        title = isVi ? 'Người thân đã tiếp nhận sự việc' : 'Relative Acknowledged Incident';
        icon = Icons.person_pin_circle_rounded;
        color = AppColors.stateAcknowledged;
        break;
      case 'INCIDENT_RESOLVED':
      case 'RESOLVED':
        title = isVi ? 'Sự cố đã được giải quyết an toàn' : 'Incident Resolved & Safe';
        icon = Icons.check_circle_rounded;
        color = AppColors.stateActive;
        break;
      case 'CHECK_IN_REQUESTED':
        title = isVi ? 'Hệ thống gửi yêu cầu xác nhận hoạt động' : 'Check-in Requested by System';
        icon = Icons.help_outline_rounded;
        color = AppColors.stateCheckInRequired;
        break;
      case 'CHECK_IN_RECEIVED':
        title = isVi ? 'Người dùng báo an toàn: "Tôi vẫn ổn"' : 'User Confirmed "I am okay"';
        icon = Icons.favorite_rounded;
        color = AppColors.stateActive;
        break;
      case 'MONITOR_NOTIFIED':
        title = isVi ? 'Đã gửi thông báo khẩn cho người thân' : 'Emergency Alert Sent to Relatives';
        icon = Icons.notifications_active_rounded;
        color = AppColors.stateAlertTriggered;
        break;
      case 'REMINDER_SENT':
        title = isVi ? 'Gửi nhắc nhở xác nhận bình an' : 'Wellness Reminder Sent';
        icon = Icons.notifications_none_rounded;
        color = AppColors.stateCheckInRequired;
        break;
      case 'PUSH_SENT':
        title = isVi ? 'Đã gửi thông báo đẩy đến điện thoại' : 'Push Notification Sent';
        icon = Icons.send_rounded;
        color = AppColors.primary;
        break;
      case 'PUSH_FAILED':
        title = isVi ? 'Gửi thông báo đẩy không thành công' : 'Push Notification Failed';
        icon = Icons.sms_failed_rounded;
        color = AppColors.stateAlertTriggered;
        break;
      case 'WARNING_TRIGGERED':
        title = isVi ? 'Cảnh báo nguy cơ không hoạt động' : 'Inactivity Warning Detected';
        icon = Icons.error_outline_rounded;
        color = AppColors.stateCheckInRequired;
        break;
      default:
        title = type.isEmpty
            ? (isVi ? 'Cập nhật diễn biến' : 'Event Update')
            : type.replaceAll('_', ' ');
        icon = Icons.timeline_rounded;
        color = AppColors.primary;
        break;
    }

    final List<String> details = [];

    // Reason explanation
    final rawReason = metadata['reason']?.toString();
    if (rawReason != null && rawReason.isNotEmpty) {
      String reasonLabel;
      switch (rawReason.toUpperCase()) {
        case 'DEVICE_OFFLINE':
          reasonLabel = 'Thiết bị mất kết nối / không thể liên lạc';
          break;
        case 'INACTIVITY':
        case 'EXTENDED_INACTIVITY':
          reasonLabel = 'Không phát hiện hoạt động vượt quá ngưỡng cho phép';
          break;
        case 'MISSED_CHECK_IN':
          reasonLabel = 'Không phản hồi yêu cầu xác nhận bình an đúng hạn';
          break;
        case 'CRITICAL_BATTERY_INACTIVITY':
          reasonLabel = 'Pin thiết bị ở mức cạn kiệt (< 15%) và không có cử động';
          break;
        case 'MANUAL_SOS':
          reasonLabel = 'Kích hoạt cảnh báo khẩn cấp thủ công';
          break;
        default:
          reasonLabel = rawReason;
      }
      details.add('Nguyên nhân: $reasonLabel');
    }

    // Risk score
    final risk = metadata['riskScore'];
    if (risk != null) {
      details.add('Mức độ rủi ro: $risk/100');
    }

    // Previous status
    final prev = metadata['previousStatus']?.toString();
    if (prev != null && prev.isNotEmpty) {
      details.add('Trạng thái trước: $prev');
    }

    // Note / resolution note
    final note = (metadata['note'] ?? metadata['resolutionNote'])?.toString();
    if (note != null && note.isNotEmpty) {
      details.add('Ghi chú: "$note"');
    }

    final formattedTime = timestamp != null
        ? DateFormat('HH:mm:ss • dd/MM/yyyy').format(timestamp.toLocal())
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator with vertical connecting line
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withAlpha(35),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Center(
                  child: Icon(icon, size: 16, color: color),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.divider,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Event Content Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (formattedTime != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...details.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

