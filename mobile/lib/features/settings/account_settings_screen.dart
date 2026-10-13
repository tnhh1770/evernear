import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_provider.dart';
import '../auth/auth_provider.dart';
import 'language_settings_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _isSubmitting = false;

  void _showEditNameDialog(AuthProvider auth) {
    final controller = TextEditingController(text: auth.currentUser?.fullName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('account_edit_name_title', fallback: 'Edit Full Name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('auth_full_name_label', fallback: 'Full Name'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('common_cancel', fallback: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.of(ctx).pop();
                setState(() => _isSubmitting = true);
                final ok = await auth.updateProfile(fullName: newName);
                if (mounted) {
                  setState(() => _isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? context.tr('account_update_profile_success', fallback: 'Profile updated successfully!')
                          : (auth.getErrorMessage(context) ?? auth.errorMessage ?? context.tr('common_retry', fallback: 'Retry'))),
                      backgroundColor: ok ? AppColors.stateActive : AppColors.stateAlertTriggered,
                    ),
                  );
                }
              }
            },
            child: Text(context.tr('common_save', fallback: 'Save')),
          ),
        ],
      ),
    );
  }

  void _showEditPhoneDialog(AuthProvider auth) {
    final controller = TextEditingController(text: auth.currentUser?.phone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('account_edit_phone_title', fallback: 'Edit Emergency Phone')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.tr('auth_phone_label', fallback: 'Phone number (for emergency alerts)'),
                hintText: 'VD: +84912345678',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('account_phone_note', fallback: 'Phone number used for emergency SMS alerts if safety check-in is missed.'),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('common_cancel', fallback: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPhone = controller.text.trim();
              Navigator.of(ctx).pop();
              setState(() => _isSubmitting = true);
              final ok = await auth.updateProfile(phone: newPhone);
              if (mounted) {
                setState(() => _isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? context.tr('account_update_profile_success', fallback: 'Profile updated successfully!')
                        : (auth.getErrorMessage(context) ?? auth.errorMessage ?? context.tr('common_retry', fallback: 'Retry'))),
                    backgroundColor: ok ? AppColors.stateActive : AppColors.stateAlertTriggered,
                  ),
                );
              }
            },
            child: Text(context.tr('common_save', fallback: 'Save')),
          ),
        ],
      ),
    );
  }

  void _showEditAvatarDialog(AuthProvider auth) {
    final controller = TextEditingController(text: auth.currentUser?.avatarUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('account_edit_avatar_title', fallback: 'Edit Avatar')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('account_avatar_label', fallback: 'Avatar'),
            hintText: context.tr('account_avatar_url_hint', fallback: 'Enter image URL (https://...)'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('common_cancel', fallback: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              Navigator.of(ctx).pop();
              setState(() => _isSubmitting = true);
              final ok = await auth.updateProfile(avatarUrl: newUrl);
              if (mounted) {
                setState(() => _isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? context.tr('account_update_profile_success', fallback: 'Profile updated successfully!')
                        : (auth.getErrorMessage(context) ?? auth.errorMessage ?? context.tr('common_retry', fallback: 'Retry'))),
                    backgroundColor: ok ? AppColors.stateActive : AppColors.stateAlertTriggered,
                  ),
                );
              }
            },
            child: Text(context.tr('common_save', fallback: 'Save')),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(AuthProvider auth) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? localError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(context.tr('account_change_password', fallback: 'Change Password')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (localError != null) ...[
                  Text(
                    localError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('account_current_password', fallback: 'Current Password'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('account_new_password', fallback: 'New Password'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('account_confirm_password', fallback: 'Confirm New Password'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.tr('common_cancel', fallback: 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final oldPass = oldPasswordController.text;
                final newPass = newPasswordController.text;
                final confirmPass = confirmPasswordController.text;

                if (oldPass.isEmpty || newPass.isEmpty) {
                  setDialogState(() {
                    localError = context.tr('auth_password_hint', fallback: 'Please enter password');
                  });
                  return;
                }
                if (newPass.length < 6) {
                  setDialogState(() {
                    localError = context.tr('auth_password_min_length', fallback: 'Password must be at least 6 characters');
                  });
                  return;
                }
                if (newPass != confirmPass) {
                  setDialogState(() {
                    localError = context.tr('account_password_mismatch', fallback: 'New passwords do not match');
                  });
                  return;
                }

                Navigator.of(ctx).pop();
                setState(() => _isSubmitting = true);
                final ok = await auth.changePassword(oldPassword: oldPass, newPassword: newPass);
                if (!mounted) return;
                setState(() => _isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? context.tr('account_password_success', fallback: 'Password changed successfully!')
                        : (auth.getErrorMessage(context) ?? auth.errorMessage ?? context.tr('common_retry', fallback: 'Retry'))),
                    backgroundColor: ok ? AppColors.stateActive : AppColors.stateAlertTriggered,
                  ),
                );
              },
              child: Text(context.tr('common_confirm', fallback: 'Confirm')),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(AuthProvider auth) {
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
              if (!mounted) return;
              if (success) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('settings_delete_success', fallback: 'Account has been successfully deleted.')),
                    backgroundColor: AppColors.primaryDark,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(auth.getErrorMessage(context) ?? auth.errorMessage ??
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

  Future<void> _showLogoutConfirmDialog(AuthProvider auth) async {
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

    if (confirmed == true && mounted) {
      await auth.logout();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    LocaleProvider? localeProvider;
    try {
      localeProvider = Provider.of<LocaleProvider>(context);
    } catch (_) {
      localeProvider = null;
    }

    final providerName = user?.authProvider?.toUpperCase() ?? 'LOCAL';
    final isGoogle = providerName == 'GOOGLE';
    final isApple = providerName == 'APPLE';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('account_settings_title', fallback: 'Account Settings')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                // Avatar & Main Info Card
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.startsWith('http'))
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: (user?.avatarUrl == null || !user!.avatarUrl!.startsWith('http'))
                            ? Text(
                                (user?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            onPressed: () => _showEditAvatarDialog(auth),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    user?.fullName ?? context.tr('common_default_user_name', fallback: 'User'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                Center(
                  child: Text(
                    user?.email ?? '',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 24),

                // Section 1: Profile Information
                Text(
                  context.tr('account_profile_header', fallback: 'Profile Information'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline, color: AppColors.primary),
                        title: Text(context.tr('account_name_label', fallback: 'Full Name')),
                        subtitle: Text(user?.fullName ?? ''),
                        trailing: const Icon(Icons.edit_outlined, size: 18),
                        onTap: () => _showEditNameDialog(auth),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.email_outlined, color: AppColors.secondary),
                        title: Text(context.tr('account_email_label', fallback: 'Email')),
                        subtitle: Text(user?.email ?? ''),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
                        title: Text(context.tr('account_phone_label', fallback: 'Emergency Phone Number')),
                        subtitle: Text(
                          (user?.phone != null && user!.phone!.isNotEmpty)
                              ? user.phone!
                              : context.tr('common_not_set', fallback: 'Not set'),
                          style: TextStyle(
                            color: (user?.phone != null && user!.phone!.isNotEmpty)
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                        trailing: const Icon(Icons.edit_outlined, size: 18),
                        onTap: () => _showEditPhoneDialog(auth),
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.language, color: AppColors.primary),
                        title: Text(context.tr('settings_language_label', fallback: 'Language')),
                        subtitle: Text(
                          localeProvider?.getLanguageDisplayName(context) ??
                              (user?.preferredLanguage ?? 'English'),
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 2: Connected Provider
                Text(
                  context.tr('account_provider_label', fallback: 'Sign-in Method'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isGoogle
                            ? Icons.g_mobiledata
                            : isApple
                                ? Icons.apple
                                : Icons.lock_outline,
                        color: isGoogle
                            ? Colors.red
                            : isApple
                                ? Colors.black
                                : AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isGoogle
                                  ? context.tr('account_provider_google', fallback: 'Google Account')
                                  : isApple
                                      ? context.tr('account_provider_apple', fallback: 'Apple Account')
                                      : context.tr('account_provider_email', fallback: 'Email & Password Account'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isGoogle || isApple
                                  ? context.tr('account_provider_oauth_desc', fallback: 'Secured via identity provider authentication')
                                  : context.tr('account_provider_local_desc', fallback: 'Secured with personal password'),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.stateActive.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          context.tr('account_status_connected', fallback: 'Connected'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.stateActive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 3: Security & Password
                if (!isGoogle && !isApple) ...[
                  Text(
                    context.tr('account_security_header', fallback: 'Security & Password'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.lock_reset, color: AppColors.primary),
                      title: Text(context.tr('account_change_password', fallback: 'Change Password')),
                      subtitle: Text(
                        context.tr('account_change_password_sub', fallback: 'Update your password to keep your account safe'),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _showChangePasswordDialog(auth),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Section 4: Account Actions
                Text(
                  context.tr('account_danger_zone', fallback: 'Account Actions'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showLogoutConfirmDialog(auth),
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
                OutlinedButton.icon(
                  onPressed: () => _showDeleteAccountDialog(auth),
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
