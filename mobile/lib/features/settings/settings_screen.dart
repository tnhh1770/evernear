import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../auth/auth_provider.dart';
import '../devices/devices_screen.dart';
import '../../core/i18n/locale_provider.dart';
import '../pairing/qr_invite_screen.dart';
import 'account_settings_screen.dart';
import 'language_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _openQrInviteScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrInviteScreen()),
    );
  }

  void _openAccountSettingsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('settings_privacy', fallback: 'Privacy Policy')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('privacy_title_1', fallback: '1. No privacy invasion'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('privacy_desc_1',
                    fallback: 'Carely never accesses your camera, microphone, or private messages.'),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('privacy_title_2', fallback: '2. No continuous location tracking'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('privacy_desc_2',
                    fallback: 'Geographic location is only obtained once during Check-in or emergency rescue events.'),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('privacy_title_3', fallback: '3. Data sovereignty'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('privacy_desc_3',
                    fallback: 'You can delete your account and all activity history at any time.'),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('settings_privacy_got_it', fallback: 'Understood')),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('settings_delete_account_confirm_title', fallback: 'Confirm Account Deletion'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          context.tr('settings_delete_account_confirm_desc',
              fallback: 'This action cannot be undone. All your personal data, devices, and safety monitoring history will be permanently deleted.'),
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('common_cancel', fallback: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await auth.deleteAccount();
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('settings_delete_success', fallback: 'Account has been successfully deleted.')),
                    backgroundColor: AppColors.primaryDark,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(auth.getErrorMessage(context) ??
                        context.tr('settings_delete_error', fallback: 'Could not delete account. Please try again later.')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('settings_delete_account_confirm_button', fallback: 'Confirm Delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutConfirmDialog(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          ctx.tr('settings_logout_confirm_title', fallback: 'Confirm Sign Out'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          ctx.tr('settings_logout_confirm_desc', fallback: 'Are you sure you want to sign out of this account?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('common_cancel', fallback: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stateAlertTriggered,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(ctx.tr('settings_logout', fallback: 'Sign Out')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('settings_title', fallback: 'Settings & Account')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // Profile Card - Clickable to open AccountSettingsScreen
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openAccountSettingsScreen(context),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.startsWith('http'))
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: (user?.avatarUrl == null || !user!.avatarUrl!.startsWith('http'))
                          ? Text(
                              (user?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? context.tr('monitored_relative_default', fallback: 'Relative'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          if (user?.phone != null && user!.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              user.phone!,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Menu items
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.primary),
                  title: Text(context.tr('account_settings_title', fallback: 'Account Settings')),
                  subtitle: Text(context.tr('account_settings_sub', fallback: 'View & edit profile, security')),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _openAccountSettingsScreen(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.qr_code, color: AppColors.primary),
                  title: Text(context.tr('settings_invite_code', fallback: 'My Pairing Code')),
                  subtitle: Text(context.tr('settings_invite_code_sub', fallback: 'Generate code for relatives to monitor you')),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _openQrInviteScreen(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.devices, color: AppColors.secondary),
                  title: Text(context.tr('settings_devices', fallback: 'Manage Devices')),
                  subtitle: Text(context.tr('settings_devices_sub', fallback: 'View registered smartphones')),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DevicesScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),

                // Language Settings Navigation Entry
                Builder(
                  builder: (ctx) {
                    LocaleProvider? localeProvider;
                    try {
                      localeProvider = Provider.of<LocaleProvider>(ctx);
                    } catch (_) {
                      localeProvider = null;
                    }
                    final langDisplayName = localeProvider?.currentLanguageDisplayName ?? 'Tiếng Việt (Tự động)';
                    return ListTile(
                      leading: const Icon(Icons.language, color: AppColors.primary),
                      title: Text(ctx.tr('settings_language_label', fallback: 'Ngôn ngữ / Language')),
                      subtitle: Text(
                        langDisplayName,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.of(ctx).push(
                          MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
                        );
                      },
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.security, color: AppColors.primary),
                  title: Text(context.tr('settings_privacy', fallback: 'Privacy Policy')),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _showPrivacyDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          ElevatedButton.icon(
            onPressed: () => _showLogoutConfirmDialog(context, auth),
            icon: const Icon(Icons.logout),
            label: Text(context.tr('settings_logout', fallback: 'Sign Out')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.stateAlertTriggered,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          // Delete Account Button (Req 5)
          OutlinedButton.icon(
            onPressed: () => _showDeleteAccountDialog(context, auth),
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: Text(
              context.tr('settings_delete_account', fallback: 'Delete Account'),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
