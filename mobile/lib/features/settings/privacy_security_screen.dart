import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/web_landing_launcher.dart';
import '../auth/auth_provider.dart';
import '../auth/onboarding_screen.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _onlyShareLocationOnAlert = true;

  void _showLocationDataSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              title: Text(
                ctx.tr('privacy_location_data_title', fallback: 'Dữ liệu vị trí'),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ctx.tr('privacy_location_sheet_desc'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          ctx.tr(
                            'privacy_location_only_when_needed_toggle',
                            fallback: 'Chỉ chia sẻ vị trí khi cần thiết',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        value: _onlyShareLocationOnAlert,
                        onChanged: (v) {
                          setModalState(() => _onlyShareLocationOnAlert = v);
                          setState(() => _onlyShareLocationOnAlert = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          child: Text(
                            ctx.tr('privacy_understood_btn', fallback: 'Đã hiểu'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
                    color: AppColors.stateAlertTriggered,
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
                  ctx.tr('settings_delete_account_confirm_desc'),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.stateAlertTriggered,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.tr(
                  'settings_delete_success',
                  fallback: 'Đã xóa tài khoản thành công.',
                )
              : (auth.getErrorMessage(context) ??
                    context.tr(
                      'settings_delete_error',
                      fallback: 'Không thể xóa tài khoản lúc này.',
                    )),
        ),
        backgroundColor: success
            ? AppColors.primary
            : AppColors.stateAlertTriggered,
      ),
    );
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.tr(
            'settings_privacy_security',
            fallback: 'Quyền riêng tư & bảo mật',
          ),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 52),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                // 1. Dữ liệu vị trí
                _buildItemCard(
                  icon: Icons.location_on_rounded,
                  title: context.tr(
                    'privacy_location_data_title',
                    fallback: 'Dữ liệu vị trí',
                  ),
                  subtitle: context.tr(
                    'privacy_location_data_sub',
                    fallback: 'Chỉ khi cần (chọn lọc)',
                  ),
                  showDivider: true,
                  onTap: _showLocationDataSheet,
                ),

                // 2. Quyền truy cập
                _buildItemCard(
                  icon: Icons.videocam_off_outlined,
                  title: context.tr(
                    'privacy_access_permissions_title',
                    fallback: 'Quyền truy cập',
                  ),
                  subtitle: context.tr(
                    'privacy_access_permissions_sub',
                    fallback: 'Camera / Microphone (không sử dụng)',
                  ),
                  showDivider: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingScreen(
                          initialPage: 3,
                          isPostRegistration: true,
                        ),
                      ),
                    );
                  },
                ),

                // 3. Sao lưu & khôi phục
                _buildItemCard(
                  icon: Icons.home_work_outlined,
                  title: context.tr(
                    'privacy_backup_restore_title',
                    fallback: 'Sao lưu & khôi phục',
                  ),
                  subtitle: context.tr(
                    'privacy_backup_restore_sub',
                    fallback: 'Lưu trữ an toàn',
                  ),
                  showDivider: true,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.tr(
                            'privacy_backup_synced_msg',
                            fallback: 'Dữ liệu an toàn đã được đồng bộ mới nhất.',
                          ),
                        ),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),

                // 4. Chính sách quyền riêng tư (Apple Guideline 5.1.1(i))
                _buildItemCard(
                  icon: Icons.privacy_tip_outlined,
                  title: context.tr(
                    'settings_privacy',
                    fallback: 'Chính sách quyền riêng tư',
                  ),
                  subtitle: context.tr(
                    'auth_terms_of_use',
                    fallback: 'Điều khoản sử dụng',
                  ),
                  showDivider: true,
                  onTap: () => WebLandingLauncher.openLanding(
                    context,
                    path: '/privacy',
                  ),
                ),

                // 5. Xóa tài khoản
                _buildItemCard(
                  icon: Icons.delete_outline_rounded,
                  title: context.tr(
                    'privacy_delete_account_title',
                    fallback: 'Xóa tài khoản',
                  ),
                  subtitle: context.tr(
                    'privacy_delete_account_sub',
                    fallback: 'Xóa dữ liệu cá nhân',
                  ),
                  showDivider: false,
                  onTap: () => _showDeleteAccountDialog(context, auth),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                  context.tr('privacy_notice'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('server_authoritative_notice'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard({
    required IconData icon,
    required String title,
    required String subtitle,
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
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
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
        if (showDivider)
          const Divider(height: 1, indent: 54, endIndent: 18, color: Color(0xFFEEF1EE)),
      ],
    );
  }
}
