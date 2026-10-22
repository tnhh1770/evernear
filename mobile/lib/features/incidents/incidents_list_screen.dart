import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/check_in_model.dart';
import '../../core/models/enums.dart';
import '../../core/widgets/calm_empty_state.dart';
import '../dashboard/dashboard_provider.dart';
import 'incident_detail_screen.dart';
import 'incidents_provider.dart';

class IncidentsListScreen extends StatefulWidget {
  final bool isEmbedded;

  const IncidentsListScreen({super.key, this.isEmbedded = false});

  @override
  State<IncidentsListScreen> createState() => _IncidentsListScreenState();
}

class _IncidentsListScreenState extends State<IncidentsListScreen> {
  static final DateFormat _dateFormat = DateFormat('HH:mm - dd/MM/yyyy');
  int _selectedFilter = 0; // 0: Tất cả, 1: An toàn, 2: Cảnh báo, 3: Xử lý

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Provider.of<IncidentsProvider>(context, listen: false).fetchIncidents();
      } catch (_) {}
    });
  }

  String _getReasonLabel(IncidentReason reason, BuildContext context) {
    switch (reason) {
      case IncidentReason.MISSED_CHECK_IN:
        return context.tr('incident_missed_check_in');
      case IncidentReason.INACTIVITY:
      case IncidentReason.EXTENDED_INACTIVITY:
        return context.tr('incident_extended_inactivity');
      case IncidentReason.DEVICE_OFFLINE:
      case IncidentReason.CRITICAL_BATTERY_INACTIVITY:
        return context.tr('incident_device_offline');
    }
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    IncidentsProvider? provider;
    try {
      provider = Provider.of<IncidentsProvider>(context);
    } catch (_) {}
    DashboardProvider? dashboard;
    try {
      dashboard = Provider.of<DashboardProvider>(context, listen: false);
    } catch (_) {}

    final allFeedItems =
        provider?.allNotifications ?? const <NotificationFeedItem>[];
    final List<NotificationFeedItem> liveItems;
    if (_selectedFilter == 1) {
      // An toàn: Check-ins & resolved incidents
      liveItems = allFeedItems.where((item) {
        if (item.type == NotificationFeedType.checkIn) return true;
        if (item.incident != null) {
          final s = item.incident!.status;
          return s == IncidentStatus.RESOLVED ||
              s == IncidentStatus.CANCELLED ||
              s == IncidentStatus.FALSE_ALARM;
        }
        return false;
      }).toList();
    } else if (_selectedFilter == 2) {
      // Cảnh báo: Active unresolved incidents (OPEN, TRIGGERED, ESCALATED)
      liveItems = allFeedItems.where((item) {
        if (item.incident != null) {
          final s = item.incident!.status;
          return s == IncidentStatus.OPEN ||
              s == IncidentStatus.TRIGGERED ||
              s == IncidentStatus.ESCALATED;
        }
        return false;
      }).toList();
    } else if (_selectedFilter == 3) {
      // Xử lý: Acknowledged incidents (ACKNOWLEDGED)
      liveItems = allFeedItems.where((item) {
        if (item.incident != null) {
          return item.incident!.status == IncidentStatus.ACKNOWLEDGED;
        }
        return false;
      }).toList();
    } else {
      liveItems = allFeedItems;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isEmbedded,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('incidents_screen_title', fallback: 'Thông báo & sự kiện'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (provider != null)
            IconButton(
              tooltip: context.tr(
                'incidents_clear_all_tooltip',
                fallback: 'Xóa tất cả',
              ),
              key: const Key('clear_all_notifications_button'),
              constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              onPressed: () async {
                final confirmed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const ClearNotificationsConfirmScreen(),
                  ),
                );
                if (confirmed == true && provider != null) {
                  await provider.clearAllNotifications();
                  dashboard?.clearUnreadNotifications();
                }
              },
              icon: const Icon(
                Icons.delete_sweep_outlined,
                size: 22,
                color: AppColors.textPrimary,
              ),
            ),
          if (provider != null && provider.unreadCount > 0)
            IconButton(
              tooltip: context.tr('notifications_mark_all_read'),
              constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              onPressed: () async {
                await provider!.markAllAsRead();
                dashboard?.clearUnreadNotifications();
              },
              icon: const Icon(
                Icons.done_all_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await provider?.fetchIncidents();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Filter chips row matching Screen 16 ("Tất cả", "An toàn", "Cảnh báo", "Xử lý")
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          0,
                          context.tr(
                            'incidents_filter_all',
                            fallback: 'Tất cả',
                          ),
                        ),
                        _buildFilterChip(
                          1,
                          context.tr(
                            'incidents_filter_safe',
                            fallback: 'An toàn',
                          ),
                        ),
                        _buildFilterChip(
                          2,
                          context.tr(
                            'incidents_filter_alert',
                            fallback: 'Cảnh báo',
                          ),
                        ),
                        _buildFilterChip(
                          3,
                          context.tr(
                            'incidents_filter_handling',
                            fallback: 'Xử lý',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Empty state when liveItems is empty
                    if (liveItems.isEmpty)
                      CalmEmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: context.tr(
                          'incident_empty_title',
                          fallback: 'Không có thông báo hoặc sự cố',
                        ),
                        description: context.tr(
                          'incident_empty_desc',
                          fallback:
                              'Mọi người thân đều đang bình an và không có cảnh báo nào.',
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Lazy virtualized SliverList for live notifications
            if (liveItems.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
                sliver: SliverList.builder(
                  itemCount: liveItems.length,
                  itemBuilder: (context, index) {
                    final item = liveItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Dismissible(
                        key: Key('dismissible_${item.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        onDismissed: (_) async {
                          final prov = provider;
                          if (prov != null) {
                            await prov.dismissNotification(item.id);
                            if (prov.unreadCount == 0) {
                              dashboard?.clearUnreadNotifications();
                            } else {
                              dashboard?.setUnreadNotificationsCount(
                                prov.unreadCount,
                              );
                            }
                          }
                        },
                        child: _buildLiveFeedItem(
                          context,
                          item,
                          provider!,
                          dashboard,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard({
    required Widget leadingWidget,
    required String title,
    required String subtitle,
    bool isAlert = false,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isAlert ? const Color(0xFFFCECE9) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isAlert ? const Color(0xFFF4CEC7) : AppColors.cardBorder,
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leadingWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
      ),
    );
  }

  Widget _buildLiveFeedItem(
    BuildContext context,
    NotificationFeedItem item,
    IncidentsProvider provider,
    DashboardProvider? dashboard,
  ) {
    if (item.type == NotificationFeedType.checkIn && item.checkIn != null) {
      final CheckInModel checkIn = item.checkIn!;
      final name = checkIn.displayName.isNotEmpty
          ? checkIn.displayName
          : context.tr('relationship_family_member', fallback: 'Người thân');
      final dateStr = _dateFormat.format(checkIn.occurredAt.toLocal());
      return _buildEventCard(
        leadingWidget: Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        title: context.tr(
          'recent_activities_confirmed_safe',
          args: {'name': name},
          fallback: '$name đã xác nhận an toàn',
        ),
        subtitle: dateStr,
      );
    }

    if (item.incident != null) {
      final incident = item.incident!;
      final dateStr = _dateFormat.format(incident.triggeredAt.toLocal());
      final isResolved = incident.status == IncidentStatus.RESOLVED;
      return _buildEventCard(
        isAlert: !isResolved,
        leadingWidget: Icon(
          isResolved ? Icons.check_circle_rounded : Icons.warning_rounded,
          color: isResolved ? AppColors.accent : AppColors.danger,
          size: 20,
        ),
        title: _getReasonLabel(incident.reason, context),
        subtitle: dateStr,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IncidentDetailScreen(incident: incident),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class ClearNotificationsConfirmScreen extends StatelessWidget {
  const ClearNotificationsConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          context.tr(
            'incidents_clear_all_confirm_title',
            fallback: 'Xóa tất cả thông báo?',
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_sweep_rounded,
                      color: AppColors.danger,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(
                    'incidents_clear_all_confirm_desc',
                    fallback:
                        'Tất cả thông báo và sự cố sẽ bị xóa khỏi danh sách. Bạn có chắc chắn muốn tiếp tục?',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.tr('common_cancel', fallback: 'Hủy'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.tr(
                            'incidents_clear_all_confirm_button',
                            fallback: 'Xóa tất cả',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }
}

