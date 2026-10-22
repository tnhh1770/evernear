import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/api_endpoints.dart';

/// Handles navigation to the Landing Page:
/// - On Web (`kIsWeb == true`): navigates to `/` (or the target web route) within the web app.
/// - On Mobile App (`kIsWeb == false`): opens the external web browser (`LaunchMode.externalApplication`)
///   so the landing page is never rendered inside the mobile app.
class WebLandingLauncher {
  /// Optional override for testing Web vs. Mobile App behavior in unit/widget tests.
  static bool? debugIsWebOverride;

  /// Optional callback override for intercepting external URL launches in widget tests.
  static Future<bool> Function(Uri uri, LaunchMode mode)?
      debugExternalLaunchOverride;

  /// History of externally launched URIs (useful for verification in tests).
  static final List<Uri> launchedExternalUris = <Uri>[];

  /// Returns true when running on Flutter Web (or overridden in tests).
  static bool get isWeb => debugIsWebOverride ?? kIsWeb;

  /// Launches the external browser to the web landing page.
  static Future<bool> openExternalLanding([String path = '/']) async {
    final uri = ApiEndpoints.resolveWebLandingUri(path);
    launchedExternalUris.add(uri);

    if (debugExternalLaunchOverride != null) {
      return debugExternalLaunchOverride!(uri, LaunchMode.externalApplication);
    }

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[WebLandingLauncher] Failed to launch external URL $uri: $e');
      return false;
    }
  }

  /// Opens the landing page according to platform rules:
  /// - Web: navigates to `/` (LandingScreen).
  /// - App: jumps out to the external web browser and never renders LandingScreen in-app.
  static Future<void> openLanding(
    BuildContext context, {
    String path = '/',
  }) async {
    if (isWeb) {
      final target = path.isEmpty ? '/' : path;
      Navigator.of(context).pushNamedAndRemoveUntil(target, (route) => false);
      return;
    }

    await openExternalLanding(path);
  }
}
