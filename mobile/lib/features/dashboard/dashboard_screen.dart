import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/realtime_service.dart';
import '../../core/services/web_landing_launcher.dart';
import '../../core/storage/local_storage.dart';
import '../../core/widgets/active_account_chip.dart';
import '../../core/widgets/evenear_illustrations.dart';
import '../check_in/check_in_screen.dart';
import '../incidents/incidents_list_screen.dart';
import '../incidents/incidents_provider.dart';
import '../settings/settings_screen.dart';
import 'dashboard_provider.dart';
import 'monitored_view.dart';
import 'monitor_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _realtimeSub = RealtimeService().eventStream.listen((event) {
      if (!mounted) return;
      _handleRealtimeAlert(event);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final token = await LocalStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        RealtimeService().connect(token);
      }
      if (mounted) {
        Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData();
        Provider.of<IncidentsProvider>(context, listen: false).fetchIncidents();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    RealtimeService().disconnect();
    super.dispose();
  }

  void _handleRealtimeAlert(Map<String, dynamic> event) async {
    final type = event['type']?.toString();
    if (type == 'CHECK_IN_CONFIRMED') {
      final senderUserId = event['userId']?.toString();
      final currentUserId = await LocalStorage.getUserId();
      if (!mounted) return;
      if (senderUserId != null && senderUserId != currentUserId) {
        final rawName = event['userDisplayName']?.toString();
        final name = (rawName != null && rawName.isNotEmpty)
            ? rawName
            : (context.tr('relationship_family_member', fallback: 'Người thân'));
        final message = context.tr(
          'check_in_guardian_notif',
          args: {'name': name},
          fallback: '💚 $name vừa xác nhận: "Tôi vẫn ổn"!',
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.stateActive,
              duration: const Duration(seconds: 4),
            ),
          );
      }
    } else if (type == 'CHECK_IN_PROMPT') {
      final recipientId = event['recipientUserId']?.toString();
      final currentUserId = await LocalStorage.getUserId();
      if (!mounted) return;
      if (recipientId == null || recipientId == currentUserId) {
        final promptText = context.tr('check_in_prompt');
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      promptText,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.stateCheckInRequired,
              duration: const Duration(seconds: 6),
            ),
          );
      }
    } else if (type == 'INCIDENT_CREATED' || type == 'INCIDENT_ESCALATED') {
      if (!mounted) return;
      Provider.of<IncidentsProvider>(context, listen: false).fetchIncidents();
      final alertText = context.tr('incident_missed_check_in');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alertText,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.stateAlertTriggered,
            duration: const Duration(seconds: 6),
          ),
        );
    }
  }

  final List<Widget> _screens = const [
    MonitoredView(),
    MonitorView(),
    IncidentsListScreen(isEmbedded: true),
    SettingsScreen(isEmbedded: true),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.select<DashboardProvider, int>((p) => p.selectedTabIndex);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: (currentIndex == 2 || currentIndex == 3)
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              title: InkWell(
                key: const Key('dashboard_landing_link'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => WebLandingLauncher.openLanding(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const EvenearHeartLogo(size: 28),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          context.tr('app_name', fallback: 'Evenear'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontSize: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: const [
                ActiveAccountAppBarAction(compact: true),
              ],
              backgroundColor: AppColors.surface,
              elevation: 0,
              scrolledUnderElevation: 0.5,
            ),
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 58,
        height: 58,
        margin: const EdgeInsets.only(top: 8),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          elevation: 3,
          backgroundColor: AppColors.primary,
          tooltip: context.tr('check_in_button'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CheckInScreen()),
            );
          },
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 8,
        color: AppColors.surface,
        padding: const EdgeInsets.only(bottom: 12),
        height: 76,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _buildNavTab(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: context.tr('nav_status'),
              ),
            ),
            Expanded(
              child: _buildNavTab(
                index: 1,
                icon: Icons.group_outlined,
                activeIcon: Icons.group_rounded,
                label: context.tr('nav_family'),
              ),
            ),
            const SizedBox(width: 56),
            Expanded(
              child: _buildIncidentsNavTab(
                index: 2,
                label: context.tr('nav_incidents'),
              ),
            ),
            Expanded(
              child: _buildNavTab(
                index: 3,
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: context.tr('nav_settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTab({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = context.select<DashboardProvider, bool>((p) => p.selectedTabIndex == index);
    final color = isSelected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: () => context.read<DashboardProvider>().setSelectedTabIndex(index),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSelected ? activeIcon : icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentsNavTab({
    required int index,
    required String label,
  }) {
    final isSelected = context.select<DashboardProvider, bool>((p) => p.selectedTabIndex == index);
    final color = isSelected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: () => context.read<DashboardProvider>().setSelectedTabIndex(index),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Selector2<DashboardProvider, IncidentsProvider, ({int count, bool hasIncidents})>(
            selector: (_, dash, inc) {
              final dCount = dash.unreadNotificationsCount;
              final iCount = inc.unreadCount;
              final hasLoadedFeed = inc.allNotifications.isNotEmpty || inc.readCount > 0;
              final effectiveCount = hasLoadedFeed
                  ? iCount
                  : (iCount > dCount ? iCount : dCount);
              final hasIncidents = hasLoadedFeed
                  ? inc.hasUnreadIncidents
                  : (inc.hasUnreadIncidents || dash.activeIncidentsCount > 0);
              return (count: effectiveCount, hasIncidents: hasIncidents);
            },
            builder: (context, data, child) {
              final count = data.count;
              final badgeColor = data.hasIncidents
                  ? AppColors.stateAlertTriggered
                  : AppColors.stateActive;
              return Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                backgroundColor: badgeColor,
                textColor: Colors.white,
                child: child!,
              );
            },
            child: Icon(
              isSelected ? Icons.notifications_rounded : Icons.notifications_none_outlined,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
