import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/device_model.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/local_storage.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

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
        _devices = list.map((j) => DeviceModel.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('[DevicesScreen] Load devices error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _revokeDevice(String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('devices_revoke', fallback: 'Unlink')),
        content: Text(ctx.tr('devices_revoke_confirm', fallback: 'Are you sure you want to disconnect this device from Carely?')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.tr('common_cancel', fallback: 'Cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.stateAlertTriggered),
            child: Text(ctx.tr('devices_revoke', fallback: 'Unlink'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await _apiClient.dio.delete(ApiEndpoints.revokeDevice(deviceId));
        if (response.statusCode == 200) {
          _loadDevices();
        }
      } catch (e) {
        debugPrint('[DevicesScreen] Revoke error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('devices_title', fallback: 'My Devices')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDevices,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Educational notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.primaryDark, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr('devices_heartbeat_notice',
                                fallback:
                                    'Periodic heartbeat signals only verify network connectivity and battery status. Heartbeat does NOT count as user activity.'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ..._devices.map((device) {
                    final isThisDevice = device.id == _currentDeviceId;
                    final heartbeatStr = device.lastHeartbeatAt != null
                        ? DateFormat('HH:mm - dd/MM').format(device.lastHeartbeatAt!.toLocal())
                        : context.tr('devices_no_heartbeat', fallback: 'No heartbeat yet');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isThisDevice ? AppColors.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      color: AppColors.surface,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        device.platform.name == 'IOS'
                                            ? Icons.apple
                                            : Icons.phone_android,
                                        color: AppColors.textPrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          device.deviceModel ?? context.tr('devices_phone_default', fallback: 'Phone'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isThisDevice) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            context.tr('devices_this_device', fallback: 'This device'),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primaryDark,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (device.isActive && !isThisDevice)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppColors.stateAlertTriggered),
                                    onPressed: () => _revokeDevice(device.id),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('devices_os_version',
                                  args: {'version': device.osVersion ?? 'N/A'},
                                  fallback: 'OS: ${device.osVersion ?? "N/A"}'),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('devices_last_heartbeat',
                                  args: {'time': heartbeatStr},
                                  fallback: 'Last heartbeat: $heartbeatStr'),
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            if (device.batteryLevel != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    device.isCharging == true
                                        ? Icons.battery_charging_full
                                        : Icons.battery_std,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.tr('devices_battery_info',
                                        args: {
                                          'level': '${device.batteryLevel}',
                                          'charging': device.isCharging == true
                                              ? context.tr('devices_charging', fallback: '(Charging)')
                                              : '',
                                        },
                                        fallback:
                                            'Battery: ${device.batteryLevel}% ${device.isCharging == true ? "(Charging)" : ""}'),
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
