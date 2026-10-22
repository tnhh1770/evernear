import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request notification permission gracefully (Android 13+ & iOS).
  /// Never crashes or blocks the user if denied.
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;

    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied || status.isRestricted) {
        return false;
      }

      final result = await Permission.notification.request();
      debugPrint('[PermissionService] Notification permission result: ${result.name}');
      return result.isGranted;
    } catch (e) {
      debugPrint('[PermissionService] Error requesting notification permission: $e');
      return false;
    }
  }

  /// Single-shot location retrieval with strict 5-second timeout and graceful degradation.
  /// If permission is denied, location service is disabled, or timeout occurs,
  /// returns null smoothly without throwing any exceptions.
  Future<Map<String, double>?> getSingleShotLocation() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        debugPrint('[PermissionService] Location service is disabled on device');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint(
            '[PermissionService] Location permission denied. Proceeding gracefully with null.');
        return null;
      }

      // Single-shot location with low accuracy (battery efficient, fast lock) and 5s timeout
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      debugPrint(
          '[PermissionService] Single-shot location failed or timed out: $e. Graceful fallback to null.');
      return null;
    }
  }

  /// Request camera permission gracefully for QR scanning (Android & iOS).
  /// Never throws or crashes if permission is denied.
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      if (status.isGranted) return true;

      final result = await Permission.camera.request();
      debugPrint('[PermissionService] Camera permission result: ${result.name}');
      return result.isGranted;
    } catch (e) {
      debugPrint('[PermissionService] Error requesting camera permission: $e');
      return false;
    }
  }

  /// Check if camera permission is permanently denied.
  Future<bool> isCameraPermanentlyDenied() async {
    try {
      return await Permission.camera.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }
}
