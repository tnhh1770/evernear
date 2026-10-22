import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_provider.dart';
import '../auth/auth_provider.dart';
import '../devices/devices_screen.dart';
import '../monitoring/monitoring_settings_screen.dart';
import '../pairing/qr_invite_screen.dart';
import 'account_settings_screen.dart';
import 'language_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_security_screen.dart';

/// Screen 5.1 — Menu cài đặt
class SettingsScreen extends StatelessWidget {
  final bool isEmbedded;

  const SettingsScreen({super.key, this.isEmbedded = false});

  Future<void> _showLogoutConfirmDialog(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ctx.tr('settings_logout_confirm_title', fallback: 'Xác nhận đăng xuất'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ctx.tr(
                    'settings_logout_confirm_desc',
                    fallback: 'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?',
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
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          ctx.tr('common_cancel', fallback: 'Hủy'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(ctx.tr('settings_logout', fallback: 'Đăng xuất')),
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

    if (confirmed == true && context.mounted) {
      await auth.logout();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ctx.tr(
                    'settings_delete_account_confirm_title',
                    fallback: 'Xác nhận xóa tài khoản',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ctx.tr(
                    'settings_delete_account_confirm_desc',
                    fallback:
                        'Hành động này không thể hoàn tác. Toàn bộ dữ liệu cá nhân, thiết bị và lịch sử theo dõi an toàn sẽ bị xóa vĩnh viễn.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(ctx.tr('common_cancel', fallback: 'Hủy')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          ctx.tr(
                            'settings_delete_account_confirm_button',
                            fallback: 'Xác nhận',
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

    if (confirmed != true || !context.mounted) return;
    final success = await auth.deleteAccount();
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'settings_delete_success',
              fallback: 'Đã xóa tài khoản thành công.',
            ),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.getErrorMessage(context) ??
                context.tr(
                  'settings_delete_error',
                  fallback: 'Không thể xóa tài khoản lúc này.',
                ),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AuthProvider? auth;
    try {
      auth = Provider.of<AuthProvider>(context);
    } catch (_) {}

    LocaleProvider? localeProvider;
    try {
      localeProvider = Provider.of<LocaleProvider>(context);
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !isEmbedded,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('settings_title', fallback: 'Cài đặt & Tài khoản'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                // 1. Thông tin cá nhân
                _buildMenuCard(
                  icon: Icons.person_outline_rounded,
                  label: context.tr(
                    'settings_personal_info',
                    fallback: 'Thông tin cá nhân',
                  ),
                  showDivider: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AccountSettingsScreen(),
                      ),
                    );
                  },
                ),

                // 2. Người thân & ủy quyền
                _buildMenuCard(
                  icon: Icons.people_outline_rounded,
                  label: context.tr(
                    'settings_relatives_authorization',
                    fallback: 'Người thân & ủy quyền',
                  ),
                  showDivider: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QrInviteScreen(),
                      ),
                    );
                  },
                ),

                // 3. Giám sát & nhắc nhở
                _buildMenuCard(
                  icon: Icons.access_time_rounded,
                  label: context.tr(
                    'settings_monitoring_reminders',
                    fallback: 'Giám sát & nhắc nhở',
                  ),
                  showDivider: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MonitoringSettingsScreen(),
                      ),
                    );
                  },
                ),

                // 4. Thiết bị
                _buildMenuCard(
                  icon: Icons.smartphone_rounded,
                  label: context.tr('settings_devices_menu', fallback: 'Thiết bị'),
                  showDivider: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DevicesScreen(),
                      ),
                    );
                  },
                ),

                // 5. Quyền riêng tư & bảo mật
                _buildMenuCard(
                  icon: Icons.shield_outlined,
                  label: context.tr(
                    'settings_privacy_security',
                    fallback: 'Quyền riêng tư & bảo mật',
                  ),
                  showDivider: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacySecurityScreen(),
                      ),
                    );
                  },
                ),

                // 6. Thông báo
                _buildMenuCard(
                  icon: Icons.notifications_none_rounded,
                  label: context.tr(
                    'settings_notifications_menu',
                    fallback: 'Cài đặt thông báo',
                  ),
                  showDivider: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                ),

                // 7. Ngôn ngữ
                _buildMenuCard(
                  icon: Icons.language_rounded,
                  label: context.tr(
                    'settings_language_label',
                    fallback: 'Ngôn ngữ / Language',
                  ),
                  subtitle:
                      localeProvider?.currentLanguageDisplayName ??
                      context.tr('settings_language_auto_vi'),
                  showDivider: false,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LanguageSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          if (auth != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _showLogoutConfirmDialog(context, auth!),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(context.tr('settings_logout', fallback: 'Đăng xuất')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _showDeleteAccountDialog(context, auth!),
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
              label: Text(
                context.tr('settings_delete_account', fallback: 'Xóa tài khoản vĩnh viễn'),
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String label,
    String? subtitle,
    bool showDivider = true,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 54, endIndent: 18, color: Color(0xFFEEF1EE)),
      ],
    );
  }
}
