import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/widgets/calm_empty_state.dart';
import '../incidents/incidents_provider.dart';
import 'check_in_screen.dart';

class RecentActivitiesScreen extends StatelessWidget {
  final bool showAppBar;

  const RecentActivitiesScreen({super.key, this.showAppBar = false});

  @override
  Widget build(BuildContext context) {
    IncidentsProvider? incidentsProvider;
    try {
      incidentsProvider = Provider.of<IncidentsProvider>(context);
    } catch (_) {}

    final feed = incidentsProvider?.allNotifications ?? [];
    final displayItems = feed.map((item) {
      if (item.type == NotificationFeedType.checkIn && item.checkIn != null) {
        final c = item.checkIn!;
        final name = c.displayName.isNotEmpty
            ? c.displayName
            : context.tr('relationship_family_member', fallback: 'Người thân');
        return {
          'title': context.tr(
            'recent_activities_confirmed_safe',
            args: {'name': name},
            fallback: '$name đã xác nhận an toàn',
          ),
          'timestamp':
              DateFormat('dd/MM/yyyy • HH:mm').format(c.occurredAt.toLocal()),
          'icon': Icons.check_circle_outline_rounded,
        };
      } else if (item.incident != null) {
        final inc = item.incident!;
        return {
          'title': inc.resolutionNote ??
              context.tr(
                'recent_activities_safety_alert',
                fallback: 'Cảnh báo an toàn',
              ),
          'timestamp': DateFormat('dd/MM/yyyy • HH:mm')
              .format(inc.triggeredAt.toLocal()),
          'icon': Icons.warning_amber_rounded,
        };
      }
      return {
        'title': context.tr(
          'recent_activities_safety_activity',
          fallback: 'Hoạt động an toàn',
        ),
        'timestamp':
            DateFormat('dd/MM/yyyy • HH:mm').format(item.timestamp.toLocal()),
        'icon': Icons.shield_outlined,
      };
    }).toList();

    final listContent = SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 20),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        children: [
        if (!showAppBar) ...[
          Text(
            context.tr('recent_activities_title', fallback: 'Hoạt động gần đây'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF184A3E),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (displayItems.isEmpty)
          CalmEmptyState(
            icon: Icons.history_rounded,
            title: context.tr('recent_activities_empty_title'),
            description: context.tr('recent_activities_empty_desc'),
            action: ElevatedButton.icon(
              key: const Key('empty_check_in_button'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckInScreen()),
                );
              },
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(
                context.tr('check_in_screen_title', fallback: 'Xác nhận an toàn'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          )
        else ...[
          Text(
            context.tr('recent_activities_today_section', fallback: 'Hôm nay'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF184A3E),
            ),
          ),
          const SizedBox(height: 12),
          // Unified white card containing activity items
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8ECE8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF184A3E).withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < displayItems.length; i++) ...[
                  _buildActivityRow(displayItems[i]),
                  if (i < displayItems.length - 1)
                    const Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: Color(0xFFEEF2EE),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
      ),
    );

    if (showAppBar) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBFAF8),
        appBar: AppBar(
          title: Text(
            context.tr('recent_activities_title', fallback: 'Hoạt động gần đây'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF184A3E),
            ),
          ),
          backgroundColor: const Color(0xFFFBFAF8),
          elevation: 0,
        ),
        body: listContent,
      );
    }

    return listContent;
  }

  Widget _buildActivityRow(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFDCEEE4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item['icon'] as IconData,
              color: const Color(0xFF28594B),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF184A3E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item['timestamp'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5A766D),
                    fontWeight: FontWeight.w500,
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
