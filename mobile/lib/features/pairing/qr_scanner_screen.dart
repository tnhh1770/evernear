import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/permission_service.dart';
import '../../core/widgets/calm_error_card.dart';
import '../dashboard/dashboard_provider.dart';
import 'qr_code_parser.dart';

/// Full-screen camera barcode scanner with Calm UX overlay,
/// automated test environment safety (MissingPluginException proof),
/// and graceful fallback to manual alphanumeric code entry.
class QrScannerScreen extends StatefulWidget {
  final bool? isTestMode;
  final Function(String code)? onCodeScanned;

  const QrScannerScreen({
    super.key,
    this.isTestMode,
    this.onCodeScanned,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController? _scannerController;
  bool _isProcessing = false;
  bool _cameraPermissionDenied = false;
  bool _isTestEnvironment = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkEnvironmentAndPermissions();
  }

  void _checkEnvironmentAndPermissions() async {
    // Headless test safety check
    final isTesting = widget.isTestMode ??
        (WidgetsBinding.instance is! WidgetsFlutterBinding ||
            WidgetsBinding.instance.runtimeType.toString().contains('AutomatedTestWidgetsFlutterBinding'));

    if (isTesting) {
      setState(() {
        _isTestEnvironment = true;
      });
      return;
    }

    final granted = await PermissionService().requestCameraPermission();
    if (!granted) {
      if (mounted) setState(() => _cameraPermissionDenied = true);
      return;
    }

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _processScannedCode(String rawCode) async {
    if (_isProcessing) return;
    final code = QrCodeParser.extractInviteCode(rawCode);
    if (code == null) return;

    setState(() => _isProcessing = true);

    if (widget.onCodeScanned != null) {
      widget.onCodeScanned!(code);
      setState(() => _isProcessing = false);
      return;
    }

    final dashboard = Provider.of<DashboardProvider>(context, listen: false);
    final success = await dashboard.acceptInviteCode(code);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('guardian_connect_success', fallback: 'Connected successfully!')),
          backgroundColor: AppColors.stateActive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() => _isProcessing = false);
      final errorMsg = dashboard.getErrorMessage(context) ??
          context.tr('guardian_connect_failed', fallback: 'Invalid or expired invitation code.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.stateAlertTriggered,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showManualInputDialog() {
    _manualController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('qr_scanner_manual_dialog_title', fallback: 'Enter Connection Code')),
        content: SingleChildScrollView(
          child: TextField(
            key: const Key('manual_code_input_field'),
            controller: _manualController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: ctx.tr('guardian_add_dialog_hint', fallback: 'VD: CR-ABC12345'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.tr('common_cancel', fallback: 'Cancel')),
          ),
          ElevatedButton(
            key: const Key('manual_code_submit_button'),
            onPressed: () {
              final code = _manualController.text.trim();
              if (code.isNotEmpty) {
                Navigator.of(ctx).pop();
                _processScannedCode(code);
              }
            },
            child: Text(ctx.tr('guardian_connect_button', fallback: 'Connect')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraPermissionDenied) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('qr_scanner_camera_title', fallback: 'Scan QR Code')), elevation: 0),
        backgroundColor: AppColors.background,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: CalmErrorCard(
              message: context.tr('qr_permission_needed',
                  fallback:
                      'Carely needs camera access to scan connection QR codes. You can grant access in Settings or enter the code manually.'),
              retryText: context.tr('qr_scanner_manual_action', fallback: 'Enter code manually'),
              onRetry: _showManualInputDialog,
            ),
          ),
        ),
      );
    }

    if (_isTestEnvironment) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('qr_scanner_connect_title', fallback: 'Scan Connection QR')), elevation: 0),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner, size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(context.tr('qr_simulated_title', fallback: 'Safe Camera Simulation Mode')),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('simulated_qr_input'),
                  controller: _manualController,
                  decoration: InputDecoration(
                    labelText: context.tr('qr_simulated_label', fallback: 'Simulated QR String'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('simulated_qr_submit'),
                  onPressed: () {
                    if (_manualController.text.isNotEmpty) {
                      _processScannedCode(_manualController.text);
                    }
                  },
                  child: Text(context.tr('qr_simulated_submit', fallback: 'Trigger Simulated Scan')),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const Key('open_manual_input_button'),
                  onPressed: _showManualInputDialog,
                  icon: const Icon(Icons.keyboard_outlined),
                  label: Text(context.tr('qr_enter_code_manually', fallback: 'Enter code manually')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.tr('qr_scanner_camera_title', fallback: 'Scan QR Code')),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_scannerController != null) ...[
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _scannerController!.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: () => _scannerController!.switchCamera(),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          if (_scannerController != null)
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null) {
                    _processScannedCode(raw);
                    break;
                  }
                }
              },
            ),

          // Calm Viewfinder Overlay
          _buildViewfinderOverlay(context),

          // Bottom Manual Input Bar
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              key: const Key('open_manual_input_button'),
              onPressed: _showManualInputDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.keyboard_outlined),
              label: Text(
                context.tr('qr_enter_code_manually', fallback: 'Enter code manually'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewfinderOverlay(BuildContext context) {
    const double cutOutSize = 240.0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: cutOutSize,
            height: cutOutSize,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2.5),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              context.tr('qr_point_camera', fallback: 'Point camera at your relative\\'),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

