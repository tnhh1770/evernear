import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/device_model.dart';
import '../../core/network/api_client.dart';
import '../../core/services/heartbeat_service.dart';
import '../../core/storage/local_storage.dart';
import '../../core/widgets/calm_empty_state.dart';
import '../auth/auth_provider.dart';

class DevicesScreen extends StatefulWidget {
  final bool showAppBar;

  const DevicesScreen({super.key, this.showAppBar = true});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final ApiClient _apiClient = ApiClient();
  List<DeviceModel> _devices = [];
  String? _currentDeviceId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    _currentDeviceId = await LocalStorage.getDeviceId();
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.devices);
      if (response.statusCode == 200) {
        final List list = response.data as List;
        _devices = list
            .map((j) => DeviceModel.fromJson(j))
            .where((d) => !d.id.startsWith('dev-') && d.isActive)
            .toList();
      }
    } catch (e) {
      debugPrint('[DevicesScreen] Load devices error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _syncCurrentDevice() async {
    setState(() => _isLoading = true);
    try {
      AuthProvider? auth;
      try {
        auth = Provider.of<AuthProvider>(context, listen: false);
      } catch (_) {}
      if (auth != null) {
        await auth.registerCurrentDevice();
      }
      await HeartbeatService().sendHeartbeat(force: true);
      await _loadDevices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'devices_sync_success',
              fallback: 'Đã đồng bộ thông tin thiết bị hiện tại.',
            ),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'devices_sync_error',
              fallback: 'Không thể đồng bộ thiết bị lúc này.',
            ),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _revokeDevice(String deviceId, {bool isCurrentDevice = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
                  ctx.tr(
                    'devices_revoke',
                    fallback: 'Hủy liên kết',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ctx.tr('devices_revoke_confirm'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.5,
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
                          backgroundColor: AppColors.stateAlertTriggered,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          ctx.tr('devices_revoke', fallback: 'Hủy liên kết'),
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

    if (confirm == true) {
      try {
        bool success = false;
        try {
          final response = await _apiClient.dio.delete(
            ApiEndpoints.deleteDevice(deviceId),
          );
          success = response.statusCode == 200 || response.statusCode == 204;
        } catch (_) {
          final fallbackRes = await _apiClient.dio.post(
            ApiEndpoints.revokeDevice(deviceId),
          );
          success = fallbackRes.statusCode == 200 || fallbackRes.statusCode == 201;
        }

        if (success) {
          if (isCurrentDevice || deviceId == _currentDeviceId) {
            await LocalStorage.saveDeviceId('');
            _currentDeviceId = null;
          }
          if (mounted) {
            setState(() {
              _devices.removeWhere((d) => d.id == deviceId);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr('devices_revoke', fallback: 'Hủy liên kết'),
                ),
                backgroundColor: AppColors.primary,
              ),
            );
          }
          await _loadDevices();
        }
      } catch (e) {
        debugPrint('[DevicesScreen] Revoke error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('common_error_unknown', fallback: 'Đã xảy ra lỗi.'),
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _devices.map((d) {
      final isThis = d.id == _currentDeviceId;
      return {
        'id': d.id,
        'name': d.deviceModel ??
            context.tr('devices_mobile_default', fallback: 'Thiết bị di động'),
        'status': d.isActive
            ? context.tr('devices_status_active', fallback: 'Hoạt động')
            : context.tr('devices_status_inactive', fallback: 'Tạm ngưng'),
        'battery': d.lastBatteryLevel,
        'isThisDevice': isThis,
        'icon': d.platform.name == 'IOS'
            ? Icons.phone_iphone_rounded
            : Icons.smartphone_rounded,
      };
    }).toList();

    final body = _isLoading && _devices.isNotEmpty
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        : RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadDevices,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 20),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 52),
                children: [
                if (!widget.showAppBar) ...[
                  Text(
                    context.tr(
                      'devices_your_devices_title',
                      fallback: 'Thiết bị của bạn',
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF184A3E),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_devices.isEmpty)
                  CalmEmptyState(
                    icon: Icons.devices_other_rounded,
                    title: context.tr(
                      'devices_empty_title',
                      fallback: 'Chưa có thiết bị nào',
                    ),
                    description: context.tr('devices_empty_desc'),
                    action: ElevatedButton.icon(
                      key: const Key('empty_add_device_button'),
                      onPressed: _syncCurrentDevice,
                      icon: const Icon(Icons.sync_rounded, size: 20),
                      label: Text(
                        context.tr(
                          'devices_sync_current_button',
                          fallback: 'Đồng bộ thiết bị hiện tại',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  )
                else ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE8ECE8)),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF184A3E).withValues(alpha: 0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < displayItems.length; i++) ...[
                          _buildDeviceRow(displayItems[i]),
                          if (i < displayItems.length - 1)
                            const Divider(
                              height: 1,
                              indent: 74,
                              endIndent: 16,
                              color: Color(0xFFEEF2EE),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: _syncCurrentDevice,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE8ECE8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.sync_rounded,
                              color: Color(0xFF28594B),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.tr(
                                'devices_sync_current_button',
                                fallback: 'Đồng bộ thiết bị hiện tại',
                              ),
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF28594B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              ),
            ),
          );

    if (!widget.showAppBar) return body;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF8),
      appBar: AppBar(
        title: Text(
          context.tr('devices_your_devices_title', fallback: 'Thiết bị của bạn'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF184A3E),
          ),
        ),
        backgroundColor: const Color(0xFFFBFAF8),
        elevation: 0,
      ),
      body: body,
    );
  }

  Widget _buildDeviceRow(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final status = item['status'] as String;
    final battery = item['battery'] as int?;
    final batteryStr = battery != null ? '$battery%' : '--%';
    final id = item['id'] as String?;
    final isThisDevice = item['isThisDevice'] == true;
    final thisDeviceLabel = context.tr('devices_this_device', fallback: 'Thiết bị này');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFDCEEE4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item['icon'] as IconData? ?? Icons.phone_iphone_rounded,
              color: const Color(0xFF28594B),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isThisDevice ? '$name ($thisDeviceLabel)' : name,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF184A3E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$status • $batteryStr',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5A766D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (id != null)
            TextButton.icon(
              onPressed: () => _revokeDevice(id, isCurrentDevice: isThisDevice),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.stateAlertTriggered,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.stateAlertTriggered,
              ),
              label: Text(
                context.tr('devices_revoke', fallback: 'Hủy liên kết'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.stateAlertTriggered,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
