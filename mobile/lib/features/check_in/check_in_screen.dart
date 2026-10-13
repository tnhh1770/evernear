import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/i18n/app_localizations.dart';
import '../dashboard/dashboard_provider.dart';
import '../demo/showcase_demo_mode.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _noteController = TextEditingController();
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadBattery();
  }

  Future<void> _loadBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    } catch (_) {}
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submitCheckIn() async {
    final demoController = ShowcaseDemoController();
    if (demoController.isDemoActive) {
      demoController.performQuickDemoCheckIn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('demo_check_in_success', fallback: 'Peace of mind check-in confirmed! (Demo Simulation)')),
            backgroundColor: AppColors.stateActive,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() => _isSubmitting = true);
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);

    final success = await dashboard.sendCheckIn(
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      batteryLevel: _batteryLevel,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        final message = dashboard.lastCheckInOffline
            ? context.tr('check_in_offline_success', fallback: AppStrings.checkInOfflineSuccess)
            : context.tr('check_in_success', fallback: AppStrings.checkInSuccess);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.stateActive,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.stateAlertTriggered,
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(context.tr('check_in_error', fallback: 'Safety confirmation saved locally. Will sync automatically once online.')),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('check_in_title', fallback: 'Safety Check-in')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Calming icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(25),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 54,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Title & Subtitle
              Text(
                context.tr('check_in_prompt', fallback: AppStrings.checkInPrompt),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('check_in_subtitle', fallback: 'Are you doing okay? Please tap to confirm.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),

              // Main Check-in button ("I'm Okay")
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitCheckIn,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 28),
                label: Text(
                  context.tr('check_in_button', fallback: AppStrings.checkInButton),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 30),

              // Quick Status Preset Tags
              Text(
                context.tr('check_in_quick_hints', fallback: 'Quick suggestions:'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  context.tr('check_in_hint_woke_up', fallback: '☕ Just woke up'),
                  context.tr('check_in_hint_cooking', fallback: '🍳 Cooking a meal'),
                  context.tr('check_in_hint_arrived_home', fallback: '🏡 Just got home'),
                  context.tr('check_in_hint_sleeping', fallback: '🌙 Going to sleep'),
                  context.tr('check_in_hint_exercise', fallback: '🏃 Walking / Exercising'),
                ].map((tag) {
                  return ActionChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onPressed: () {
                      _noteController.text = tag;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Optional Note Field
              TextField(
                controller: _noteController,

                maxLines: 2,
                decoration: InputDecoration(
                  hintText: context.tr('check_in_note_hint', fallback: AppStrings.checkInNoteHint),
                  prefixIcon: const Icon(Icons.edit_note_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: 24),

              // Battery & Device info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _batteryLevel > 20 ? Icons.battery_charging_full : Icons.battery_alert,
                            color: _batteryLevel > 20 ? AppColors.primary : AppColors.stateGracePeriod,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.tr('check_in_battery_current',
                                  args: {'level': '$_batteryLevel'},
                                  fallback: 'Current battery: $_batteryLevel%'),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reassurance info
              Text(
                context.tr('check_in_calm_reassurance',
                    fallback: 'Note: You do not need to keep the app open. Normal phone usage is passively recognized.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
