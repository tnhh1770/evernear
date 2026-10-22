import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/enums.dart';
import '../../core/models/incident_model.dart';
import '../../core/network/realtime_service.dart';
import '../../core/storage/local_storage.dart';
import '../dashboard/dashboard_provider.dart';
import '../dashboard/relative_detail_screen.dart';
import 'incidents_provider.dart';

/// Section 4 — HỆ THỐNG CẢNH BÁO & XỬ LÝ SỰ CỐ
/// Supports:
/// - Screen 4.1: Cảnh báo (step 0)
/// - Screen 4.2: Chi tiết sự cố (step 1)
/// - Screen 4.3: Xử lý sự cố (step 2)
/// Preserves RBAC behavior for Monitored vs Guardian users when [incident] is provided.
class IncidentDetailScreen extends StatefulWidget {
  final IncidentModel? incident;
  final String? incidentId;
  final bool showcaseMode;
  final int initialStep;

  const IncidentDetailScreen({
    super.key,
    this.incident,
    this.incidentId,
    this.showcaseMode = false,
    int? initialStep,
    int? initialPage,
  }) : initialStep = initialStep ?? initialPage ?? 0;

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  IncidentModel? _incident;
  bool _isLoading = false;
  bool _isInitialFetching = false;
  StreamSubscription? _realtimeSub;
  String? _currentUserId;
  late int _currentStep;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _loadCurrentUserId();
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

  Future<void> _loadCurrentUserId() async {
    final uid = await LocalStorage.getUserId();
    if (mounted) {
      setState(() => _currentUserId = uid);
    }
  }

  Future<void> _fetchInitialDetail(String id) async {
    try {
      final provider = Provider.of<IncidentsProvider>(context, listen: false);
      final detail = await provider.getIncidentDetail(id);
      if (!mounted) return;
      setState(() {
        _isInitialFetching = false;
        if (detail != null) {
          _incident = detail;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isInitialFetching = false);
      }
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _refreshDetail() async {
    final id = _incident?.id ?? widget.incidentId;
    if (id == null) return;
    try {
      final provider = Provider.of<IncidentsProvider>(context, listen: false);
      final detail = await provider.getIncidentDetail(id);
      if (detail != null && mounted) {
        setState(() => _incident = detail);
      }
    } catch (_) {}
  }

  void _acknowledge() async {
    if (_incident == null) return;
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<IncidentsProvider>(context, listen: false);
      final ok = await provider.acknowledgeIncident(_incident!.id);
      if (mounted) {
        setState(() => _isLoading = false);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('incident_status_acknowledged', fallback: 'Đã tiếp nhận xử lý'),
              ),
              backgroundColor: AppColors.primary,
            ),
          );
          _refreshDetail();
          Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveIncident({bool falseAlarm = false}) async {
    if (_incident == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            falseAlarm
                ? context.tr(
                    'incident_false_alarm_recorded',
                    fallback: 'Đã ghi nhận báo động giả',
                  )
                : context.tr(
                    'incident_marked_resolved',
                    fallback: 'Đã đánh dấu xử lý sự cố',
                  ),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<IncidentsProvider>(context, listen: false);
      final note = _noteController.text.trim().isEmpty
          ? (falseAlarm
              ? context.tr(
                  'incident_false_alarm_btn',
                  fallback: 'Báo động giả',
                )
              : null)
          : _noteController.text.trim();
      final ok = await provider.resolveIncident(
        _incident!.id,
        resolutionNote: note,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'incident_resolved_done',
                  fallback: 'Đã hoàn tất xử lý sự cố.',
                ),
              ),
              backgroundColor: AppColors.primary,
            ),
          );
          Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData();
          Navigator.of(context).pop();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialFetching) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    DashboardProvider? dashboard;
    try {
      dashboard = Provider.of<DashboardProvider>(context, listen: false);
    } catch (_) {}
    IncidentsProvider? incidentsProv;
    try {
      incidentsProv = Provider.of<IncidentsProvider>(context, listen: false);
    } catch (_) {}

    final currentUserId =
        _currentUserId ?? dashboard?.currentUserId ?? incidentsProv?.currentUserId;
    final isMonitoredUser = _incident != null &&
        currentUserId != null &&
        _incident!.monitoredUserId == currentUserId;

    final titles = [
      context.tr('incident_step_alert', fallback: 'Cảnh báo'),
      context.tr('incident_step_detail', fallback: 'Chi tiết sự cố'),
      context.tr('incident_step_resolve', fallback: 'Xử lý sự cố'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          titles[_currentStep.clamp(0, 2)],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step selector pills so user can view 4.1 Cảnh báo, 4.2 Chi tiết sự cố, 4.3 Xử lý sự cố
            if (!isMonitoredUser) ...[
              Row(
                children: [
                  _buildStepTab(
                    0,
                    context.tr('incident_step_alert', fallback: 'Cảnh báo'),
                  ),
                  const SizedBox(width: 8),
                  _buildStepTab(
                    1,
                    context.tr(
                      'incident_step_detail',
                      fallback: 'Chi tiết sự cố',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStepTab(
                    2,
                    context.tr(
                      'incident_step_resolve',
                      fallback: 'Xử lý sự cố',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (isMonitoredUser)
              _buildMonitoredUserSafetyCard(_incident!)
            else ...[
              if (_currentStep == 0) _buildStepAlertCard(),
              if (_currentStep == 1) _buildStepIncidentDetail(),
              if (_currentStep == 2) _buildStepResolveIncident(),

              // Preserve RBAC buttons when a real IncidentModel is passed
              if (_incident != null && _incident!.status != IncidentStatus.RESOLVED) ...[
                const SizedBox(height: 20),
                if (_incident!.status != IncidentStatus.ACKNOWLEDGED) ...[
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _acknowledge,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      context.tr('incident_acknowledge_button'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _resolveIncident(),
                  icon: const Icon(Icons.done_all, size: 20),
                  label: Text(
                    context.tr('incident_resolve_button'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepTab(int index, String label) {
    final selected = _currentStep == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentStep = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0xFFE6E8E5),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// Screen 17 (4.1) — Cảnh báo (17_incident_alert.png)
  Widget _buildStepAlertCard() {
    final triggeredDateStr = _incident != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format(_incident!.triggeredAt.toLocal())
        : '--:--';
    final alertTitle = context.tr(
      'incident_no_response',
      fallback: 'Không nhận được phản hồi',
    );
    final alertDesc = _incident?.resolutionNote?.isNotEmpty == true
        ? _incident!.resolutionNote!
        : context.tr(
            'incident_no_response_desc',
            fallback:
                'Người thân chưa xác nhận an toàn trong khoảng thời gian dự kiến',
          );
    final severityLabel = _incident != null
        ? (_incident!.riskScore >= 70
            ? context.tr('incident_risk_high', fallback: 'Cao')
            : (_incident!.riskScore >= 40
                ? context.tr('incident_risk_medium', fallback: 'Trung bình')
                : context.tr('incident_risk_low', fallback: 'Thấp')))
        : context.tr('incident_risk_standard', fallback: 'Tiêu chuẩn');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFCECE9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF4CEC7), width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFAD7D2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        'incident_safety_alert_title',
                        fallback: 'Cảnh báo an toàn',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alertTitle,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alertDesc,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'incident_time_prefix',
                        args: {'time': triggeredDateStr},
                        fallback: 'Thời gian: $triggeredDateStr',
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'incident_risk_level_prefix',
                        args: {'level': severityLabel},
                        fallback: 'Mức độ rủi ro: $severityLabel',
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              context.tr('incident_view_detail_btn', fallback: 'Xem chi tiết'),
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              DashboardProvider? dash;
              try {
                dash = Provider.of<DashboardProvider>(context, listen: false);
              } catch (_) {}
              final rel = (_incident != null && dash != null)
                  ? dash.getMonitoredRelationship(_incident!.monitoredUserId)
                  : null;
              final relName =
                  _incident?.userDisplayName ??
                  rel?.monitoredUser?.fullName ??
                  rel?.label ??
                  context.tr(
                    'monitored_relative_default',
                    fallback: 'Người thân',
                  );
              final relPhone = rel?.monitoredUser?.phone ?? '';
              final relEmail = rel?.monitoredUser?.email ?? '';
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ContactRelativeScreen(
                    name: relName,
                    statusText: context.tr(
                      'guardian_check_in_required',
                      fallback: 'Cần kiểm tra ngay',
                    ),
                    isAlert: true,
                    lastConfirmed: _incident != null
                        ? DateFormat('dd/MM/yyyy • HH:mm')
                            .format(_incident!.triggeredAt.toLocal())
                        : '--:--',
                    location: context.tr(
                      'guardian_location_when_needed',
                      fallback: 'Vị trí (chỉ khi cần)',
                    ),
                    phone: relPhone,
                    email: relEmail,
                    relationship: rel,
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              context.tr('incident_call_now_btn', fallback: 'Gọi ngay'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  /// Screen 18 (4.2) — Chi tiết sự cố (18_incident_detail.png)
  Widget _buildStepIncidentDetail() {
    final summaryText = _incident != null
        ? (_incident!.reason == IncidentReason.MISSED_CHECK_IN
            ? context.tr(
                'incident_summary_missed_checkin',
                fallback: 'Không nhận được xác nhận an toàn theo lịch',
              )
            : (_incident!.reason == IncidentReason.DEVICE_OFFLINE
                ? context.tr(
                    'incident_summary_device_offline',
                    fallback: 'Thiết bị mất kết nối kéo dài',
                  )
                : context.tr(
                    'incident_summary_no_activity',
                    fallback:
                        'Không ghi nhận hoạt động trong khoảng thời gian quy định',
                  )))
        : context.tr(
            'incident_summary_normal',
            fallback: 'Không có hoạt động bất thường',
          );

    final severityLabel = _incident != null
        ? (_incident!.riskScore >= 70
            ? context.tr('incident_risk_high', fallback: 'Cao')
            : (_incident!.riskScore >= 40
                ? context.tr('incident_risk_medium', fallback: 'Trung bình')
                : context.tr('incident_risk_low', fallback: 'Thấp')))
        : context.tr('incident_risk_low', fallback: 'Thấp');
    final riskText = context.tr(
      'incident_risk_level_prefix',
      args: {'level': severityLabel},
      fallback: 'Mức độ rủi ro: $severityLabel',
    );

    final timelineItems = <String>[];
    if (_incident != null) {
      final triggerTime = DateFormat('HH:mm').format(_incident!.triggeredAt.toLocal());
      timelineItems.add(
        context.tr(
          'incident_timeline_anomaly_detected',
          args: {'time': triggerTime},
          fallback: '$triggerTime — Phát hiện bất thường',
        ),
      );
      if (_incident!.escalatedAt != null) {
        final escTime = DateFormat('HH:mm').format(_incident!.escalatedAt!.toLocal());
        timelineItems.add(
          context.tr(
            'incident_timeline_escalated',
            args: {'time': escTime},
            fallback: '$escTime — Nâng cấp cảnh báo',
          ),
        );
      }
      if (_incident!.acknowledgedAt != null) {
        final ackTime = DateFormat('HH:mm').format(_incident!.acknowledgedAt!.toLocal());
        timelineItems.add(
          context.tr(
            'incident_timeline_acknowledged',
            args: {'time': ackTime},
            fallback: '$ackTime — Đã tiếp nhận xử lý',
          ),
        );
      }
      if (_incident!.resolvedAt != null) {
        final resTime = DateFormat('HH:mm').format(_incident!.resolvedAt!.toLocal());
        timelineItems.add(
          context.tr(
            'incident_timeline_resolved',
            args: {'time': resTime},
            fallback: '$resTime — Đã giải quyết',
          ),
        );
      }
    }
    if (timelineItems.isEmpty) {
      timelineItems.add(
        context.tr(
          'incident_timeline_no_anomaly',
          args: {'time': '--:--'},
          fallback: '--:-- — Chưa ghi nhận sự kiện bất thường',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr(
                        'incident_summary_title',
                        fallback: 'Tóm tắt sự cố',
                      ),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summaryText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      riskText,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFEEF1EE)),
              ),
              Text(
                context.tr(
                  'incident_timeline_title',
                  fallback: 'Timeline sự kiện',
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < timelineItems.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _buildRedDotTimelineRow(timelineItems[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildWhiteSectionCard(
          title: context.tr(
            'incident_notif_history_title',
            fallback: 'Lịch sử thông báo',
          ),
          children: [
            Text(
              _incident?.escalatedAt != null
                  ? context.tr(
                      'incident_notif_sent_guardian',
                      args: {
                        'time': DateFormat('HH:mm').format(
                          _incident!.escalatedAt!.toLocal(),
                        ),
                      },
                      fallback:
                          'Đã gửi cảnh báo khẩn cấp đến người giám hộ (${DateFormat('HH:mm').format(_incident!.escalatedAt!.toLocal())})',
                    )
                  : (_incident != null
                      ? context.tr(
                          'incident_notif_sent_relative',
                          args: {
                            'time': DateFormat('HH:mm').format(
                              _incident!.triggeredAt.toLocal(),
                            ),
                          },
                          fallback:
                              'Đã gửi thông báo kiểm tra đến người thân (${DateFormat('HH:mm').format(_incident!.triggeredAt.toLocal())})',
                        )
                      : context.tr(
                          'incident_notif_none_sent',
                          fallback: 'Chưa có thông báo nào được gửi',
                        )),
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        'incident_last_location_title',
                        fallback: 'Vị trí gần nhất (nếu có)',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                        'incident_no_location_data',
                        fallback: 'Chưa có dữ liệu vị trí',
                      ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep = 2),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              context.tr('incident_step_resolve', fallback: 'Xử lý sự cố'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRedDotTimelineRow(String label) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Screen 19 (4.3) — Xử lý sự cố (19_incident_recovery.png)
  Widget _buildStepResolveIncident() {
    final isResolved = _incident?.status == IncidentStatus.RESOLVED;
    final contactTimestamp = _incident?.resolvedAt != null
        ? DateFormat('dd/MM/yyyy • HH:mm').format(_incident!.resolvedAt!.toLocal())
        : (_incident?.acknowledgedAt != null
            ? DateFormat('dd/MM/yyyy • HH:mm').format(_incident!.acknowledgedAt!.toLocal())
            : '--:--');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCEEE4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            'incident_contacted_relative',
                            fallback: 'Đã liên hệ với người thân',
                          ),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          contactTimestamp,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, indent: 50, color: Color(0xFFEEF1EE)),
              ),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCEEE4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            'incident_current_status_title',
                            fallback: 'Trạng thái hiện tại',
                          ),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isResolved
                              ? context.tr(
                                  'incident_currently_safe',
                                  fallback: 'Hiện tại: An toàn',
                                )
                              : context.tr(
                                  'incident_unconfirmed_status',
                                  fallback: 'Chưa xác nhận',
                                ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
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
        if (isResolved) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F1E8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFC8E3D2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFCDE5D6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          'incident_status_restored',
                          fallback: 'Đã khôi phục trạng thái',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'incident_currently_safe',
                          fallback: 'Hiện tại: An toàn',
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  'incident_resolution_note_title',
                  fallback: 'Ghi chú xử lý',
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: context.tr(
                    'incident_note_hint',
                    fallback: 'Nhập ghi chú...',
                  ),
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _resolveIncident(falseAlarm: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: Text(
              context.tr(
                'incident_mark_resolved_btn',
                fallback: 'Đánh dấu đã xử lý',
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _resolveIncident(falseAlarm: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              side: const BorderSide(color: AppColors.cardBorder),
              shape: const StadiumBorder(),
            ),
            child: Text(
              context.tr(
                'incident_false_alarm_btn',
                fallback: 'Báo động giả',
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
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
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMonitoredUserSafetyCard(IncidentModel incident) {
    final isResolved = incident.status == IncidentStatus.RESOLVED;
    final isAcknowledged = incident.status == IncidentStatus.ACKNOWLEDGED;
    final dateFormat = DateFormat('HH:mm:ss - dd/MM/yyyy');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isResolved
                  ? Icons.check_circle_rounded
                  : (isAcknowledged
                      ? Icons.support_agent_rounded
                      : Icons.sensors_rounded),
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isResolved
                ? context.tr(
                    'incident_monitored_resolved_msg',
                    fallback: 'Sự cố đã được người thân xử lý an toàn',
                  )
                : (isAcknowledged
                    ? context.tr(
                        'incident_monitored_ack_msg',
                        fallback: 'Người thân đang liên hệ hỗ trợ bạn',
                      )
                    : context.tr(
                        'incident_monitored_sent_msg',
                        fallback:
                            'Tín hiệu khẩn cấp đã được gửi tới người thân',
                      )),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'incident_monitored_time_prefix',
              args: {'time': dateFormat.format(incident.triggeredAt.toLocal())},
              fallback:
                  'Thời điểm: ${dateFormat.format(incident.triggeredAt.toLocal())}',
            ),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
