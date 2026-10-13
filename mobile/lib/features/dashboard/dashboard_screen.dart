import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/realtime_service.dart';
import '../../core/storage/local_storage.dart';
import '../check_in/check_in_screen.dart';
import '../incidents/incidents_list_screen.dart';
import '../settings/settings_screen.dart';
import 'dashboard_provider.dart';
import 'monitored_view.dart';
import 'monitor_view.dart';
import '../demo/showcase_demo_mode.dart';
import '../onboarding/product_showcase_screen.dart';

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
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _handleRealtimeAlert(Map<String, dynamic> event) async {
    final type = event['type']?.toString();
    if (type == 'CHECK_IN_CONFIRMED') {
      final senderUserId = event['userId']?.toString();
      final currentUserId = await LocalStorage.getUserId();
      if (!mounted) return;
      // Show alert if check-in was confirmed by another member (e.g. monitored member)
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
        ScaffoldMessenger.of(context).showSnackBar(
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
      }
    }

  final List<Widget> _screens = const [
    MonitoredView(),
    MonitorView(),
    IncidentsListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);
    final currentIndex = dashboard.selectedTabIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              AppStrings.appName,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr('dashboard_demo_tooltip', fallback: 'Intro & Interactive Demo'),
            icon: const Icon(Icons.campaign_outlined, color: AppColors.primary),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.explore_outlined, color: AppColors.primary),
                          title: Text(
                            context.tr('dashboard_showcase_title', fallback: 'Explore Product Showcase'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            context.tr('dashboard_showcase_desc', fallback: 'Browse feature highlights & overview slides'),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductShowcaseScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.play_circle_outline, color: AppColors.stateActive),
                          title: Text(
                            context.tr('dashboard_demo_mode_title', fallback: 'Enable Presentation Demo Mode'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            context.tr('dashboard_demo_mode_desc', fallback: 'Simulate system states for demo/recording'),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            ShowcaseDemoController().enableDemo();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () => context.read<DashboardProvider>().fetchDashboardData(),
          ),
        ],
        backgroundColor: AppColors.surface,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          const ShowcaseDemoBanner(),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.only(top: 8),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          elevation: 4,
          backgroundColor: AppColors.primary,
          tooltip: context.tr('check_in_button', fallback: 'I am okay'),
          onPressed: () {
            if (ShowcaseDemoController().isDemoActive) {
              ShowcaseDemoController().performQuickDemoCheckIn();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: Text(context.tr('demo_check_in_success', fallback: 'Peace of mind check-in confirmed! (Demo Simulation)')),
                  backgroundColor: AppColors.stateActive,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CheckInScreen()),
              );
            }
          },
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 8,
        color: AppColors.surface,
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _buildNavTab(
                index: 0,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: context.tr('nav_status', fallback: 'Status'),
              ),
            ),
            Expanded(
              child: _buildNavTab(
                index: 1,
                icon: Icons.group_outlined,
                activeIcon: Icons.group,
                label: context.tr('nav_family', fallback: 'Family'),
              ),
            ),
            const SizedBox(width: 56), // Notch gap for central circular check-in button
            Expanded(
              child: _buildIncidentsNavTab(
                index: 2,
                label: context.tr('nav_incidents', fallback: 'Incidents'),
              ),
            ),
            Expanded(
              child: _buildNavTab(
                index: 3,
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: context.tr('nav_settings', fallback: 'Settings'),
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
    final dashboard = Provider.of<DashboardProvider>(context);
    final isSelected = dashboard.selectedTabIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: () => dashboard.setSelectedTabIndex(index),
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
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
    final dashboard = Provider.of<DashboardProvider>(context);
    final isSelected = dashboard.selectedTabIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: () => dashboard.setSelectedTabIndex(index),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Selector<DashboardProvider, int>(
            selector: (_, p) => p.unreadNotificationsCount,
            builder: (context, count, child) => Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: child!,
            ),
            child: Icon(
              isSelected ? Icons.notifications : Icons.notifications_none_outlined,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
