import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/enums.dart';
import '../../core/models/check_in_model.dart';
import '../../core/models/relationship_model.dart';
import '../../core/widgets/calm_empty_state.dart';
import '../../core/widgets/calm_error_card.dart';
import '../../core/widgets/calm_loading_widget.dart';
import '../dashboard/dashboard_provider.dart';
import 'incidents_provider.dart';
import 'incident_detail_screen.dart';

class IncidentsListScreen extends StatefulWidget {
  const IncidentsListScreen({super.key});

  @override
  State<IncidentsListScreen> createState() => _IncidentsListScreenState();
}

class _IncidentsListScreenState extends State<IncidentsListScreen> {
  static final DateFormat _dateFormat = DateFormat('HH:mm - dd/MM/yyyy');
  int _selectedFilter = 0; // 0: All, 1: Peace of Mind, 2: Incidents

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<IncidentsProvider>(context, listen: false).fetchIncidents();
    });
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

  Color _getStatusColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.OPEN:
      case IncidentStatus.TRIGGERED:
        return AppColors.stateGracePeriod;
      case IncidentStatus.ESCALATED:
        return AppColors.stateAlertTriggered;
      case IncidentStatus.ACKNOWLEDGED:
        return AppColors.stateAcknowledged;
      case IncidentStatus.RESOLVED:
      case IncidentStatus.CANCELLED:
      case IncidentStatus.FALSE_ALARM:
        return AppColors.stateActive;
    }
  }

  String _getStatusLabel(IncidentStatus status, BuildContext context) {
    switch (status) {
      case IncidentStatus.OPEN:
      case IncidentStatus.TRIGGERED:
        return context.tr('incident_status_pending', fallback: 'Awaiting response');
      case IncidentStatus.ESCALATED:
        return context.tr('incident_status_alerted', fallback: 'Alert dispatched');
      case IncidentStatus.ACKNOWLEDGED:
        return context.tr('incident_status_acknowledged', fallback: 'Acknowledged');
      case IncidentStatus.RESOLVED:
        return context.tr('incident_status_resolved', fallback: 'Resolved');
      case IncidentStatus.CANCELLED:
      case IncidentStatus.FALSE_ALARM:
        return context.tr('incident_status_completed', fallback: 'Completed');
    }
  }

  void _showCheckInDetailsDialog(BuildContext context, CheckInModel checkIn) {
    final name = checkIn.displayName.isNotEmpty
        ? checkIn.displayName
        : context.tr('relationship_family_member', fallback: 'Người thân');
    final dateStr = _dateFormat.format(checkIn.occurredAt.toLocal());

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.stateActive.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.stateActive,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('check_in_detail_title', fallback: AppStrings.checkInDetailTitle),
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(dateStr, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    if (checkIn.batteryLevel != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.battery_std_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            '${checkIn.batteryLevel}%',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                    if (checkIn.note != null && checkIn.note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              checkIn.note!,
                              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    context.tr('common_confirm', fallback: 'Đã hiểu'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    final isSelected = _selectedFilter == index;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = index),
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(label),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IncidentsProvider>(context);

    // Resolve visible list according to selected filter
    final List<NotificationFeedItem> displayItems;
    if (_selectedFilter == 1) {
      displayItems = provider.incomingCheckIns
          .map((c) => NotificationFeedItem.checkIn(c))
          .toList();
    } else if (_selectedFilter == 2) {
      displayItems = provider.incidents
          .map((i) => NotificationFeedItem.incident(i))
          .toList();
    } else {
      displayItems = provider.allNotifications;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.tr('notifications_title', fallback: AppStrings.notificationsTitle),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (provider.unreadCount > 0)
            TextButton.icon(
              onPressed: () async {
                await provider.markAllAsRead();
                if (context.mounted) {
                  Provider.of<DashboardProvider>(context, listen: false)
                      .setUnreadNotificationsCount(0);
                }
              },
              icon: const Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
              label: Text(
                context.tr('notifications_mark_all_read', fallback: AppStrings.notificationsMarkAllRead),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: provider.isLoading
          ? CalmLoadingWidget(
              message: context.tr('incident_loading', fallback: 'Đang tải thông báo...'),
            )
          : RefreshIndicator(
              onRefresh: () => provider.fetchIncidents(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildFilterChip(
                            0,
                            context.tr('filter_all', fallback: AppStrings.filterAll),
                            Icons.format_list_bulleted_rounded,
                          ),
                          _buildFilterChip(
                            1,
                            context.tr('filter_check_ins', fallback: AppStrings.filterCheckIns),
                            Icons.favorite_rounded,
                          ),
                          _buildFilterChip(
                            2,
                            context.tr('filter_incidents', fallback: AppStrings.filterIncidents),
                            Icons.warning_amber_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.errorMessage != null)
                    SliverToBoxAdapter(
                      child: CalmErrorCard(
                        message: provider.errorMessage!,
                        onRetry: () => provider.fetchIncidents(),
                      ),
                    ),
                  if (displayItems.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60.0),
                        child: CalmEmptyState(
                          title: context.tr('incident_empty_title', fallback: AppStrings.calmEmptyIncidentsTitle),
                          description: _selectedFilter == 1
                              ? context.tr('notifications_empty_checkins', fallback: 'Chưa có lượt báo bình an nào.')
                              : _selectedFilter == 2
                                  ? context.tr('incident_empty_desc', fallback: AppStrings.calmEmptyIncidentsDesc)
                                  : context.tr('notifications_empty_all', fallback: AppStrings.notificationsEmptyAll),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      sliver: SliverList.builder(
                        itemCount: displayItems.length,
                        itemBuilder: (ctx, index) {
                          final item = displayItems[index];

                          if (item.type == NotificationFeedType.checkIn && item.checkIn != null) {
                            final checkIn = item.checkIn!;
                            String name = checkIn.displayName;
                            if (name.isEmpty) {
                              final dashboard = Provider.of<DashboardProvider>(context, listen: false);
                              final rel = dashboard.monitoredByMe.cast<RelationshipModel?>().firstWhere(
                                    (r) => r?.monitoredUserId == checkIn.userId,
                                    orElse: () => null,
                                  );
                              if (rel != null && rel.label != null && rel.label!.isNotEmpty) {
                                name = rel.label!;
                              } else if (rel?.monitoredUser?.fullName != null &&
                                  rel!.monitoredUser!.fullName.isNotEmpty) {
                                name = rel.monitoredUser!.fullName;
                              } else {
                                name = context.tr('relationship_family_member', fallback: 'Người thân');
                              }
                            }
                            final dateStr = _dateFormat.format(checkIn.occurredAt.toLocal());
                            final title = context.tr(
                              'check_in_feed_title',
                              args: {'name': name},
                              fallback: 'Báo bình an: $name',
                            );

                            final subtitleParts = <String>[];
                            subtitleParts.add(dateStr);
                            if (checkIn.batteryLevel != null) {
                              subtitleParts.add('Pin: ${checkIn.batteryLevel}%');
                            }
                            if (checkIn.note != null && checkIn.note!.isNotEmpty) {
                              subtitleParts.add('"${checkIn.note}"');
                            }

                            final isUnread = !provider.isRead(item.id);

                            return RepaintBoundary(
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isUnread
                                        ? AppColors.primary.withValues(alpha: 0.6)
                                        : AppColors.stateActive.withValues(alpha: 0.25),
                                    width: isUnread ? 1.5 : 1,
                                  ),
                                ),
                                color: AppColors.surface,
                                elevation: 0,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.stateActive.withValues(alpha: 0.15),
                                        child: const Icon(
                                          Icons.favorite_rounded,
                                          color: AppColors.stateActive,
                                          size: 22,
                                        ),
                                      ),
                                      if (isUnread)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.5),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      subtitleParts.join(' • '),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.stateActive.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          context.tr('check_in_badge_peace', fallback: AppStrings.checkInBadgePeace),
                                          style: const TextStyle(
                                            color: AppColors.stateActive,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (isUnread) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            context.tr('notification_unread_badge', fallback: AppStrings.notificationUnreadBadge),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  onTap: () async {
                                    if (isUnread) {
                                      await provider.markAsRead(item.id);
                                      if (context.mounted) {
                                        Provider.of<DashboardProvider>(context, listen: false)
                                            .setUnreadNotificationsCount(provider.unreadCount);
                                      }
                                    }
                                    if (context.mounted) {
                                      _showCheckInDetailsDialog(context, checkIn);
                                    }
                                  },
                                  onLongPress: () => _showCheckInDetailsDialog(context, checkIn),
                                ),
                              ),
                            );
                          }

                          // Incident Card
                          final incident = item.incident!;
                          final statusColor = _getStatusColor(incident.status);
                          final dateStr = _dateFormat.format(incident.triggeredAt.toLocal());
                          final isUnread = !provider.isRead(item.id);

                          return RepaintBoundary(
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isUnread
                                      ? AppColors.stateGracePeriod
                                      : (incident.status == IncidentStatus.ESCALATED ||
                                              incident.status == IncidentStatus.OPEN ||
                                              incident.status == IncidentStatus.TRIGGERED
                                          ? statusColor.withAlpha(100)
                                          : Colors.transparent),
                                  width: isUnread ? 1.5 : 1,
                                ),
                              ),
                              color: AppColors.surface,
                              elevation: 0,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: statusColor.withAlpha(30),
                                      child: Icon(
                                        incident.status == IncidentStatus.RESOLVED ||
                                                incident.status == IncidentStatus.CANCELLED
                                            ? Icons.check
                                            : Icons.info_outline,
                                        color: statusColor,
                                      ),
                                    ),
                                    if (isUnread)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: AppColors.stateGracePeriod,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  _getReasonLabel(incident.reason, context),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.tr(
                                        'incident_risk_level',
                                        args: {'score': '${incident.riskScore}'},
                                        fallback: 'Risk Level: ${incident.riskScore}/100',
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: incident.riskScore > 60
                                            ? AppColors.stateGracePeriod
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withAlpha(30),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusLabel(incident.status, context),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.stateGracePeriod.withAlpha(40),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          context.tr('notification_unread_badge', fallback: AppStrings.notificationUnreadBadge),
                                          style: const TextStyle(
                                            color: AppColors.stateGracePeriod,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () async {
                                  if (isUnread) {
                                    await provider.markAsRead(item.id);
                                    if (context.mounted) {
                                      Provider.of<DashboardProvider>(context, listen: false)
                                          .setUnreadNotificationsCount(provider.unreadCount);
                                    }
                                  }
                                  if (!context.mounted) return;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => IncidentDetailScreen(incident: incident),
                                    ),
                                  );
                                },
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
}
