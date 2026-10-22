import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../i18n/app_localizations.dart';
import '../models/user_model.dart';
import '../storage/local_storage.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/dashboard/dashboard_provider.dart';
import '../../features/settings/account_settings_screen.dart';

/// Resolves the active user account from [AuthProvider] or [LocalStorage] fallback,
/// and renders a compact, clickable account badge in the AppBar or screen header.
class ActiveAccountAppBarAction extends StatefulWidget {
  final bool compact;

  const ActiveAccountAppBarAction({
    super.key,
    this.compact = false,
  });

  @override
  State<ActiveAccountAppBarAction> createState() => _ActiveAccountAppBarActionState();
}

class _ActiveAccountAppBarActionState extends State<ActiveAccountAppBarAction> {
  String? _fallbackName;
  String? _fallbackEmail;

  @override
  void initState() {
    super.initState();
    _loadFallbackIdentity();
  }

  Future<void> _loadFallbackIdentity() async {
    final name = await LocalStorage.getUserName();
    final email = await LocalStorage.getUserEmail();
    if (mounted && (name != null || email != null)) {
      setState(() {
        _fallbackName = name;
        _fallbackEmail = email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AuthProvider? auth;
    try {
      auth = Provider.of<AuthProvider>(context);
    } catch (_) {
      auth = null;
    }

    final UserModel? user = auth?.currentUser;
    final String displayName = (user?.fullName != null && user!.fullName.trim().isNotEmpty)
        ? user.fullName.trim()
        : ((_fallbackName != null && _fallbackName!.trim().isNotEmpty)
            ? _fallbackName!.trim()
            : context.tr('account_active_user', fallback: 'Tài khoản'));
    final String displayEmail = (user?.email != null && user!.email.trim().isNotEmpty)
        ? user.email.trim()
        : (_fallbackEmail ?? '');
    final String initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : (displayEmail.isNotEmpty ? displayEmail.substring(0, 1).toUpperCase() : 'U');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showActiveAccountSheet(
          context,
          displayName: displayName,
          displayEmail: displayEmail,
          user: user,
          auth: auth,
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: widget.compact ? 150 : 195),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.stateActive,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!widget.compact && displayEmail.isNotEmpty)
                      Text(
                        displayEmail,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppColors.primary.withValues(alpha: 0.75),
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline banner showing the currently active user account inside screen bodies.
class ActiveAccountBanner extends StatefulWidget {
  final EdgeInsetsGeometry margin;

  const ActiveAccountBanner({
    super.key,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  State<ActiveAccountBanner> createState() => _ActiveAccountBannerState();
}

class _ActiveAccountBannerState extends State<ActiveAccountBanner> {
  String? _fallbackName;
  String? _fallbackEmail;

  @override
  void initState() {
    super.initState();
    _loadFallbackIdentity();
  }

  Future<void> _loadFallbackIdentity() async {
    final name = await LocalStorage.getUserName();
    final email = await LocalStorage.getUserEmail();
    if (mounted && (name != null || email != null)) {
      setState(() {
        _fallbackName = name;
        _fallbackEmail = email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AuthProvider? auth;
    try {
      auth = Provider.of<AuthProvider>(context);
    } catch (_) {
      auth = null;
    }

    final UserModel? user = auth?.currentUser;
    final String displayName = (user?.fullName != null && user!.fullName.trim().isNotEmpty)
        ? user.fullName.trim()
        : ((_fallbackName != null && _fallbackName!.trim().isNotEmpty)
            ? _fallbackName!.trim()
            : '');
    final String displayEmail = (user?.email != null && user!.email.trim().isNotEmpty)
        ? user.email.trim()
        : (_fallbackEmail ?? '');

    if (displayName.isEmpty && displayEmail.isEmpty) {
      return const SizedBox.shrink();
    }

    final String initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : displayEmail.substring(0, 1).toUpperCase();

    return Container(
      margin: widget.margin,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showActiveAccountSheet(
          context,
          displayName: displayName.isNotEmpty ? displayName : displayEmail,
          displayEmail: displayEmail,
          user: user,
          auth: auth,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: context.tr('account_label_prefix'),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(
                        text: displayName.isNotEmpty ? displayName : displayEmail,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (displayName.isNotEmpty && displayEmail.isNotEmpty)
                        TextSpan(
                          text: ' ($displayEmail)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.verified_user_outlined,
                size: 15,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showActiveAccountSheet(
  BuildContext context, {
  required String displayName,
  required String displayEmail,
  UserModel? user,
  AuthProvider? auth,
}) {
  DashboardProvider? dashboard;
  try {
    dashboard = Provider.of<DashboardProvider>(context, listen: false);
  } catch (_) {
    dashboard = null;
  }

  final guardiansCount = dashboard?.monitoringMe.length ?? 0;
  final monitoringCount = dashboard?.monitoredByMe.length ?? 0;
  final initial = displayName.isNotEmpty
      ? displayName.substring(0, 1).toUpperCase()
      : 'U';

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (sheetCtx) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(
            sheetCtx.tr('account_logged_in_badge'),
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
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                sheetCtx.tr('account_logged_in_badge'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (displayEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                displayEmail,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sheetCtx.tr(
                                'account_guardians_count',
                                args: {'count': '$guardiansCount'},
                              ),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 16, color: AppColors.divider),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.group_outlined,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sheetCtx.tr(
                                'account_monitoring_count',
                                args: {'count': '$monitoringCount'},
                              ),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetCtx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AccountSettingsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.manage_accounts_outlined,
                            size: 18,
                          ),
                          label: Text(sheetCtx.tr('account_profile_button')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (auth != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.of(sheetCtx).pop();
                              await auth.logout();
                            },
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: Text(sheetCtx.tr('account_switch_button')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF2F2),
                              foregroundColor: AppColors.stateAlertTriggered,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppColors.stateAlertTriggered
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
