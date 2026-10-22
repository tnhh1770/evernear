import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/widgets/evenear_illustrations.dart';
import '../auth/auth_provider.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.currentUser == null) {
          auth.refreshProfile();
        }
      } catch (_) {}
    });
  }

  void _showPersonalInfoSheet(AuthProvider auth) {
    final user = auth.currentUser;
    final nameCtrl = TextEditingController(
      text: user?.fullName ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: user?.phone ?? '',
    );
    String? localError;
    bool isSaving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ctx.tr(
                      'account_profile_header',
                      fallback: 'Thông tin cá nhân',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (localError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.stateAlertTriggered.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        localError!,
                        style: const TextStyle(
                          color: AppColors.stateAlertTriggered,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: ctx.tr(
                        'account_name_label',
                        fallback: 'Họ và tên',
                      ),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: ctx.tr(
                        'account_phone_label',
                        fallback: 'Số điện thoại khẩn cấp',
                      ),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ctx.tr(
                      'account_phone_note',
                      fallback:
                          'Số điện thoại được dùng để gửi SMS khẩn cấp khi không có phản hồi an toàn.',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.cardBorder),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(ctx.tr('common_cancel', fallback: 'Hủy')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final newName = nameCtrl.text.trim();
                                  final newPhone = phoneCtrl.text.trim();
                                  if (newName.isEmpty) {
                                    setModalState(() {
                                      localError = ctx.tr(
                                        'auth_name_required',
                                        fallback: 'Vui lòng nhập họ và tên.',
                                      );
                                    });
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(context);
                                  final successMsg = ctx.tr(
                                    'profile_update_success',
                                    fallback: 'Đã cập nhật hồ sơ thành công!',
                                  );
                                  final failMsg = ctx.tr(
                                    'profile_update_error',
                                    fallback: 'Không thể cập nhật lúc này',
                                  );
                                  setModalState(() {
                                    localError = null;
                                    isSaving = true;
                                  });
                                  final ok = await auth.updateProfile(
                                    fullName: newName,
                                    phone: newPhone,
                                  );
                                  if (!ctx.mounted) return;
                                  setModalState(() => isSaving = false);
                                  if (ok) {
                                    Navigator.of(ctx).pop();
                                    if (mounted) {
                                      setState(() {});
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(successMsg),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  } else {
                                    setModalState(() {
                                      localError =
                                          auth.getErrorMessage(ctx) ??
                                          auth.errorMessage ??
                                          failMsg;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(ctx.tr('common_save', fallback: 'Lưu')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePasswordSheet(AuthProvider auth) {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    String? localError;
    bool isSaving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ctx.tr(
                      'account_change_password',
                      fallback: 'Đổi mật khẩu',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (localError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.stateAlertTriggered.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        localError!,
                        style: const TextStyle(
                          color: AppColors.stateAlertTriggered,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: oldPasswordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: ctx.tr(
                        'account_current_password',
                        fallback: 'Mật khẩu hiện tại',
                      ),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: newPasswordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: ctx.tr(
                        'account_new_password',
                        fallback: 'Mật khẩu mới',
                      ),
                      prefixIcon: const Icon(Icons.key_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmPasswordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: ctx.tr(
                        'account_confirm_password',
                        fallback: 'Xác nhận mật khẩu mới',
                      ),
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.cardBorder),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(ctx.tr('common_cancel', fallback: 'Hủy')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final oldPass = oldPasswordCtrl.text;
                                  final newPass = newPasswordCtrl.text;
                                  final confirmPass = confirmPasswordCtrl.text;

                                  if (oldPass.isEmpty || newPass.isEmpty) {
                                    setModalState(() {
                                      localError = ctx.tr(
                                        'auth_password_hint',
                                        fallback: 'Vui lòng nhập mật khẩu',
                                      );
                                    });
                                    return;
                                  }
                                  if (newPass.length < 6) {
                                    setModalState(() {
                                      localError = ctx.tr(
                                        'auth_password_min_length',
                                        fallback: 'Mật khẩu phải từ 6 ký tự trở lên',
                                      );
                                    });
                                    return;
                                  }
                                  if (newPass != confirmPass) {
                                    setModalState(() {
                                      localError = ctx.tr(
                                        'account_password_mismatch',
                                        fallback: 'Mật khẩu xác nhận không khớp',
                                      );
                                    });
                                    return;
                                  }

                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final successMsg = ctx.tr(
                                    'account_password_success',
                                    fallback: 'Đổi mật khẩu thành công!',
                                  );
                                  final failMsg = ctx.tr(
                                    'account_error_password_failed',
                                    fallback: 'Không thể đổi mật khẩu lúc này.',
                                  );

                                  setModalState(() {
                                    localError = null;
                                    isSaving = true;
                                  });
                                  final ok = await auth.changePassword(
                                    oldPassword: oldPass,
                                    newPassword: newPass,
                                  );
                                  if (ctx.mounted) {
                                    setModalState(() => isSaving = false);
                                    if (ok) {
                                      Navigator.pop(ctx);
                                    } else {
                                      setModalState(() {
                                        localError =
                                            auth.getErrorMessage(ctx) ??
                                            auth.errorMessage ??
                                            failMsg;
                                      });
                                      return;
                                    }
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(successMsg),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(ctx.tr('common_confirm', fallback: 'Xác nhận')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final notUpdatedLabel = context.tr(
      'profile_not_updated',
      fallback: 'Chưa cập nhật',
    );
    final displayName = (user?.fullName != null && user!.fullName.isNotEmpty)
        ? user.fullName
        : notUpdatedLabel;
    final displayPhone = (user?.phone != null && user!.phone!.isNotEmpty)
        ? user.phone!
        : notUpdatedLabel;
    final displayEmail = (user?.email != null && user!.email.isNotEmpty)
        ? user.email
        : notUpdatedLabel;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: AppBar(
        title: Text(
          context.tr('profile_screen_title', fallback: 'Hồ sơ của tôi'),
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Color(0xFF184A3E),
          ),
        ),
        backgroundColor: const Color(0xFFFBFAF8),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 52),
        children: [
          // Top Avatar + Name + Email (no avatar edit trigger)
          Column(
            children: [
              const SizedBox(height: 4),
              EvenearAvatar(
                name: displayName,
                avatarUrl: user?.avatarUrl,
                radius: 42,
                showStatusDot: false,
              ),
              const SizedBox(height: 14),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF184A3E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayEmail,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF5A766D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),

          // Section 1: Personal Information Card
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    context.tr(
                      'account_profile_header',
                      fallback: 'Thông tin cá nhân',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF184A3E),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showPersonalInfoSheet(auth),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(
                    context.tr('account_edit_name_title', fallback: 'Đổi họ và tên'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
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
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: context.tr(
                    'account_name_label',
                    fallback: 'Họ và tên',
                  ),
                  value: displayName,
                  onTap: () => _showPersonalInfoSheet(auth),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 18,
                  color: Color(0xFFEEF2EE),
                ),
                _buildInfoRow(
                  icon: Icons.phone_outlined,
                  label: context.tr(
                    'account_phone_label',
                    fallback: 'Số điện thoại khẩn cấp',
                  ),
                  value: displayPhone,
                  onTap: () => _showPersonalInfoSheet(auth),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 18,
                  color: Color(0xFFEEF2EE),
                ),
                _buildInfoRow(
                  icon: Icons.email_outlined,
                  label: context.tr(
                    'account_email_label',
                    fallback: 'Email',
                  ),
                  value: displayEmail,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 2: Sign-in Method & Password Security
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              context.tr(
                'account_security_header',
                fallback: 'Bảo mật & Mật khẩu',
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF184A3E),
              ),
            ),
          ),
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
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF28594B),
                        size: 23,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                'account_provider_email',
                                fallback: 'Tài khoản Email & Mật khẩu',
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF284B40),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr(
                                'account_provider_local_desc',
                                fallback:
                                    'Đăng nhập bảo mật với mật khẩu cá nhân',
                              ),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF5A766D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.stateActive.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          context.tr(
                            'account_status_connected',
                            fallback: 'Đã kết nối',
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.stateActive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 18,
                  color: Color(0xFFEEF2EE),
                ),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onTap: () => _showChangePasswordSheet(auth),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    leading: const Icon(
                      Icons.lock_reset_rounded,
                      color: Color(0xFF28594B),
                      size: 23,
                    ),
                    title: Text(
                      context.tr(
                        'account_change_password',
                        fallback: 'Đổi mật khẩu',
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF284B40),
                      ),
                    ),
                    subtitle: Text(
                      context.tr(
                        'account_change_password_sub',
                        fallback:
                            'Cập nhật mật khẩu để bảo vệ an toàn cho tài khoản',
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF5A766D),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF8CA098),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF28594B), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF5A766D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF284B40),
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF8CA098),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
