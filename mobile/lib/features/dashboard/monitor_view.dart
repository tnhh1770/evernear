import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/enums.dart';
import '../../core/models/relationship_model.dart';
import '../../core/widgets/calm_empty_state.dart';
import '../../core/widgets/calm_error_card.dart';
import '../../core/widgets/calm_loading_widget.dart';
import '../../core/widgets/evenear_illustrations.dart';
import '../pairing/qr_invite_screen.dart';
import '../pairing/qr_scanner_screen.dart';
import 'dashboard_provider.dart';
import 'relative_detail_screen.dart';

typedef GuardianView = MonitorView;

class MonitorView extends StatelessWidget {
  const MonitorView({super.key});

  void _showAddRelativeDialog(BuildContext context) {
    final inviteController = TextEditingController();
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (ctx) => Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: Text(
                  ctx.tr(
                    'guardian_add_dialog_title',
                    fallback: 'Thêm người thân theo dõi',
                  ),
                ),
                elevation: 0,
              ),
              body: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 24),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          key: const Key('scan_qr_button'),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            final res = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => const QrScannerScreen(),
                              ),
                            );
                            if (res == true) {
                              dashboard.fetchDashboardData();
                            }
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(
                            ctx.tr(
                              'guardian_scan_qr',
                              fallback: 'Quét mã QR người thân',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const Key('dialog_create_invite_button'),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const QrInviteScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: Text(
                            ctx.tr(
                              'guardian_create_own_invite',
                              fallback: 'Tạo mã mời của tôi',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                ctx.tr(
                                  'guardian_or_enter_code',
                                  fallback: 'Hoặc nhập mã',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ctx.tr(
                            'guardian_add_dialog_desc',
                            fallback: 'Nhập mã ghép đôi từ người thân của bạn',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: inviteController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: ctx.tr(
                              'guardian_add_dialog_hint',
                              fallback: 'VD: CR-ABC12345',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(
                                ctx.tr('common_cancel', fallback: 'Hủy'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final code = inviteController.text.trim();
                                if (code.isNotEmpty) {
                                  final ok = await dashboard.acceptInviteCode(
                                    code,
                                  );
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                    final errorMsg =
                                        dashboard.getErrorMessage(context) ??
                                        context.tr(
                                          'guardian_connect_failed',
                                          fallback:
                                              'Mã kết nối không hợp lệ hoặc đã hết hạn.',
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok
                                              ? context.tr(
                                                  'guardian_connect_success',
                                                  fallback:
                                                      'Kết nối thành công!',
                                                )
                                              : errorMsg,
                                        ),
                                        backgroundColor: ok
                                            ? AppColors.stateActive
                                            : AppColors.stateAlertTriggered,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Text(
                                ctx.tr(
                                  'guardian_connect_button',
                                  fallback: 'Kết nối',
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
          ),
        )
        .whenComplete(() => inviteController.dispose());
  }

  Map<String, dynamic> _mapRelationshipToCardData(
    BuildContext context,
    RelationshipModel rel,
  ) {
    final name =
        rel.monitoredUser?.fullName ??
        rel.label ??
        context.tr('monitored_relative_default', fallback: 'Người thân');
    final state = rel.config?.currentState ?? MonitoringState.ACTIVE;
    final isAlert = state == MonitoringState.CHECK_IN_REQUIRED ||
        state == MonitoringState.ALERT_TRIGGERED ||
        state == MonitoringState.ESCALATED ||
        state == MonitoringState.WARNING;
    final lastActivity = rel.config?.lastActivityAt;
    final formattedTime = lastActivity != null
        ? DateFormat('HH:mm').format(lastActivity.toLocal())
        : null;
    final formattedFull = lastActivity != null
        ? DateFormat('dd/MM/yyyy • HH:mm').format(lastActivity.toLocal())
        : context.tr('guardian_no_activity_yet', fallback: 'Chưa có hoạt động');
    final deviceText = rel.monitoredUser?.fullName != null
        ? context.tr('guardian_relative_device', fallback: 'Thiết bị người thân')
        : context.tr('guardian_primary_device', fallback: 'Thiết bị chính');
    final locationText = rel.config?.locationEnabled == true
        ? context.tr('guardian_location_when_needed', fallback: 'Vị trí (chỉ khi cần)')
        : context.tr('guardian_no_location_shared', fallback: 'Không chia sẻ vị trí');

    return {
      'name': name,
      'statusText': isAlert
          ? context.tr('state_check_in_required')
          : context.tr('monitored_status_protected_pill', fallback: 'Đang được bảo vệ'),
      'subText': isAlert
          ? context.tr('guardian_no_confirm_received', fallback: 'Chưa nhận được xác nhận')
          : (formattedTime != null
              ? context.tr(
                  'guardian_confirmed_at_today',
                  args: {'time': formattedTime},
                  fallback: 'Lần xác nhận: $formattedTime hôm nay',
                )
              : context.tr(
                  'guardian_no_confirm_today',
                  fallback: 'Chưa có xác nhận hôm nay',
                )),
      'lastConfirmed': formattedFull,
      'isAlert': isAlert,
      'device': deviceText,
      'location': locationText,
      'phone': rel.monitoredUser?.phone ?? '',
      'email': rel.monitoredUser?.email ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);

    if (dashboard.isLoading && dashboard.monitoredByMe.isEmpty) {
      return CalmLoadingWidget(
        message: context.tr(
          'guardian_loading',
          fallback: 'Đang tải danh sách người thân...',
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => dashboard.fetchDashboardData(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
        children: [
          if (dashboard.errorMessage != null) ...[
            CalmErrorCard(
              message: dashboard.errorMessage!,
              onRetry: () => dashboard.fetchDashboardData(),
            ),
            const SizedBox(height: 12),
          ],

          // Header Row matching Screen 14 (14_guardian_people_list.png): "Danh sách người thân" + Add icon button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.tr(
                    'guardian_people_list_title',
                    fallback: 'Danh sách người thân',
                  ),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showAddRelativeDialog(context),
                tooltip: context.tr(
                  'guardian_add_person',
                  fallback: 'Thêm người thân',
                ),
                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                icon: const Icon(
                  Icons.person_add_alt_1_outlined,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (dashboard.monitoredByMe.isNotEmpty)
            ...dashboard.monitoredByMe.map(
              (rel) => _buildRelativeCard(
                context,
                _mapRelationshipToCardData(context, rel),
                relationship: rel,
              ),
            )
          else
            CalmEmptyState(
              icon: Icons.people_outline_rounded,
              title: context.tr('guardian_empty_title'),
              description: context.tr('guardian_empty_desc'),
              action: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    key: const Key('empty_scan_qr_button'),
                    onPressed: () async {
                      final res = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const QrScannerScreen(),
                        ),
                      );
                      if (res == true) {
                        dashboard.fetchDashboardData();
                      }
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: Text(
                      context.tr('guardian_scan_qr', fallback: 'Quét mã QR'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('empty_invite_code_button'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QrInviteScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: Text(
                      context.tr(
                        'guardian_create_invite',
                        fallback: 'Tạo mã mời',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRelativeCard(
    BuildContext context,
    Map<String, dynamic> data, {
    RelationshipModel? relationship,
  }) {
    final name = data['name'] as String;
    final statusText = data['statusText'] as String;
    final subText = data['subText'] as String;
    final isAlert = data['isAlert'] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RelativeDetailScreen(
                relativeData: data,
                relationship: relationship,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              EvenearAvatar(
                name: name,
                radius: 28,
                showStatusDot: false,
                statusColor: isAlert
                    ? AppColors.stateCheckInRequired
                    : AppColors.stateActive,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (relationship?.label != null &&
                        relationship!.label != name) ...[
                      const SizedBox(height: 2),
                      Text(
                        relationship.label!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isAlert
                            ? const Color(0xFFD97736)
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subText,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isAlert
                            ? const Color(0xFFD97736)
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (relationship != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          Text(
                            context.tr(
                              'guardian_risk_zero',
                              fallback: 'Nguy cơ: 0%',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            context.tr(
                              'guardian_alerts_zero',
                              fallback: '0 cảnh báo',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (relationship != null)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
