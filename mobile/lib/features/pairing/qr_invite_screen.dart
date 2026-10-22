import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/widgets/active_account_chip.dart';
import '../../core/widgets/calm_error_card.dart';
import '../../core/widgets/calm_loading_widget.dart';
import '../dashboard/dashboard_provider.dart';
import 'qr_scanner_screen.dart';

/// Screen generating and displaying a graphic QR code and large alphanumeric pairing code.
/// Follows schema evernear://invite?code=CR-XXXXXX with one-tap copy and share sheet trigger.
class QrInviteScreen extends StatefulWidget {
  final String? initialCode;

  const QrInviteScreen({super.key, this.initialCode});

  @override
  State<QrInviteScreen> createState() => _QrInviteScreenState();
}

class _QrInviteScreenState extends State<QrInviteScreen> {
  String? _inviteCode;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _inviteCode = widget.initialCode;
    } else {
      _generateCode();
    }
  }

  Future<void> _generateCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dashboard = Provider.of<DashboardProvider>(context, listen: false);
    final code = await dashboard.generateInviteCode(
      label: AppLocalizations.staticTr('family_relation_default', fallback: 'Family'),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (code != null && code.isNotEmpty) {
          _inviteCode = code;
        } else {
          _errorMessage = context.tr('connect_error', fallback: 'Could not create invite code. Please check your network connection.');
        }
      });
    }
  }

  void _copyToClipboard() {
    if (_inviteCode == null) return;
    Clipboard.setData(ClipboardData(text: _inviteCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('qr_copied', fallback: 'Invite code copied to clipboard')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareCode() {
    if (_inviteCode == null) return;
    final shareText = context.tr(
      'qr_share_message',
      args: {'code': _inviteCode!},
      fallback: 'Connect with me on Evernear: My code is $_inviteCode. Or scan in Evernear: evernear://invite?code=$_inviteCode',
    );
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('qr_share_copied', fallback: 'Invite share link copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _inviteCode != null ? 'evernear://invite?code=$_inviteCode' : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.tr('qr_invite_title', fallback: 'Pairing Invite Code'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const Key('app_bar_switch_to_scanner'),
            tooltip: context.tr('qr_action_switch_to_scanner'),
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            },
          ),
          const ActiveAccountAppBarAction(compact: true),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 20),
        child: _isLoading
            ? CalmLoadingWidget(message: context.tr('qr_invite_loading', fallback: 'Generating invite code...'))
            : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: CalmErrorCard(
                      message: _errorMessage!,
                      onRetry: _generateCode,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 52.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const ActiveAccountBanner(),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('settings_invite_dialog_desc',
                              fallback:
                                  'Share this code with your loved one to scan or enter in the app:'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 28),

                        // Graphical QR Code Card
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            key: const Key('qr_image_view'),
                            data: qrData,
                            version: QrVersions.auto,
                            size: 220.0,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Formatted Text Code with One-Tap Copy
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _inviteCode ?? '',
                                  key: const Key('invite_code_text'),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    key: const Key('copy_invite_code_button'),
                                    icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                                    tooltip: context.tr('qr_copy_tooltip', fallback: 'Copy code'),
                                    onPressed: _copyToClipboard,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Expiration Notice Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 15, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  context.tr('settings_invite_dialog_expires',
                                      fallback: 'Code expires in 48 hours.'),
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Share Action Button (Pill StadiumBorder)
                        ElevatedButton.icon(
                          key: const Key('share_invite_code_button'),
                          onPressed: _shareCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.share_outlined, size: 20),
                          label: Text(
                            context.tr('qr_share_button', fallback: 'Share invite'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          key: const Key('open_scanner_from_invite_button'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const QrScannerScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                          label: Text(
                            context.tr('qr_action_scan_relative'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

