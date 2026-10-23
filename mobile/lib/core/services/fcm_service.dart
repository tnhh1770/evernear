import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/local_storage.dart';

/// Top-level background message handler required by Firebase Messaging.
/// Must be annotated with `@pragma('vm:entry-point')` to survive tree-shaking in background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase might already be initialized or running in mock mode
  }
  debugPrint('[FCM Background] Received message: ${message.messageId}, data: ${message.data}');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  static const String notificationChannelId = 'evernear_alerts_channel';
  static const String notificationChannelName = 'Evernear Alerts & Check-Ins';
  static const String notificationChannelDesc =
      'Notifications for check-in requests, emergency incidents, and safety reminders.';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _isFirebaseAvailable = false;
  bool _isInitialized = false;

  void Function(String token)? onTokenRefreshCallback;
  void Function(Map<String, dynamic> data)? _onNotificationTapCallback;
  Map<String, dynamic>? _pendingPayload;

  void Function(Map<String, dynamic> data)? get onNotificationTapCallback => _onNotificationTapCallback;
  set onNotificationTapCallback(void Function(Map<String, dynamic> data)? callback) {
    _onNotificationTapCallback = callback;
    if (callback != null && _pendingPayload != null) {
      final payload = _pendingPayload!;
      _pendingPayload = null;
      debugPrint('[FcmService] Dispatching buffered pending notification payload: $payload');
      callback(payload);
    }
  }

  Map<String, dynamic>? get pendingPayload => _pendingPayload;

  @visibleForTesting
  void setMockPendingPayload(Map<String, dynamic> payload) {
    _pendingPayload = payload;
  }

  String? get fcmToken => _fcmToken;
  bool get isFirebaseAvailable => _isFirebaseAvailable;
  bool get isInitialized => _isInitialized;

  /// Allows unit tests to manually set an FCM token.
  @visibleForTesting
  void setMockToken(String token) {
    _fcmToken = token;
  }

  /// Initialize Firebase Core, FCM listeners, and Local Notifications.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      _isFirebaseAvailable = Firebase.apps.isNotEmpty;
      _isInitialized = true;
      return;
    }

    try {
      // 1. Initialize Firebase Core
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isFirebaseAvailable = true;
      debugPrint('[FcmService] Firebase initialized successfully.');
    } catch (e) {
      _isFirebaseAvailable = false;
      debugPrint('[FcmService] Firebase.initializeApp() skipped or unavailable: $e');
    }

    // 2. Initialize Local Notifications (for foreground alerts)
    await _initializeLocalNotifications();

    if (_isFirebaseAvailable) {
      // 3. Register Background Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Request notification permissions gracefully
      await requestNotificationPermission();

      // 5. Setup Android notification channel
      await _createNotificationChannel();

      // 6. Setup Foreground & Interaction Listeners
      _setupMessageListeners();

      // 7. Fetch initial FCM token & subscribe to token refresh
      await _retrieveToken();
    }

    _isInitialized = true;
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(response.payload!);
              onNotificationTapCallback?.call(data);
            } catch (e) {
              debugPrint('[FcmService] Error parsing notification payload: $e');
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[FcmService] Error initializing local notifications: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        notificationChannelId,
        notificationChannelName,
        description: notificationChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('[FcmService] Error creating notification channel: $e');
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (!_isFirebaseAvailable) return false;
    try {
      final NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint(
          '[FcmService] FCM permission status: ${settings.authorizationStatus}');
      return isAuthorized;
    } catch (e) {
      debugPrint('[FcmService] Error requesting FCM permission: $e');
      return false;
    }
  }

  void _setupMessageListeners() {
    // Foreground message stream
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[FcmService] Foreground message received: ${message.messageId}');
      final type = message.data['type']?.toString();
      // Calm Tech: In foreground, check-in confirmations are already rendered via in-app SnackBar.
      // Suppress redundant intrusive system heads-up banner to prevent alarm fatigue.
      if (type == 'CHECK_IN_CONFIRMED') {
        debugPrint('[FcmService] Suppressed foreground heads-up for peaceful check-in (handled by in-app UI).');
        return;
      }

      // Self-Alert Suppression: Never alert the sender or monitored user about their own incident!
      final senderUserId = message.data['senderUserId']?.toString();
      final monitoredUserId = message.data['monitoredUserId']?.toString() ?? message.data['userId']?.toString();
      final currentUserId = await LocalStorage.getUserId();
      if (currentUserId != null &&
          (senderUserId == currentUserId || monitoredUserId == currentUserId) &&
          type == 'INCIDENT_CREATED') {
        debugPrint('[FcmService] Suppressed self-alarm notification for the sender/monitored user ($currentUserId).');
        return;
      }

      showForegroundNotification(message);
    });

    // When notification is clicked and app opens from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FcmService] Notification clicked (onMessageOpenedApp): ${message.data}');
      handleMessageAction(message.data);
    });

    // Check if app was launched directly by tapping a notification from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[FcmService] App launched via initial notification: ${message.data}');
        handleMessageAction(message.data);
      }
    });
  }

  Future<String?> getToken() async {
    if (_fcmToken != null && _fcmToken!.isNotEmpty) return _fcmToken;
    if (_isFirebaseAvailable) {
      try {
        _fcmToken = await FirebaseMessaging.instance.getToken();
        if (_fcmToken != null && _fcmToken!.isNotEmpty) {
          return _fcmToken;
        }
      } catch (e) {
        debugPrint('[FcmService] Could not fetch FCM token: $e');
      }
    }
    try {
      final deviceUid = await LocalStorage.getOrCreateDeviceUid();
      _fcmToken = 'simulated-fcm-$deviceUid';
      return _fcmToken;
    } catch (_) {
      return _fcmToken;
    }
  }

  Future<void> _retrieveToken() async {
    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('[FcmService] Initial FCM Token: $_fcmToken');
      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        onTokenRefreshCallback?.call(_fcmToken!);
      }

      // Listen for token updates
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[FcmService] FCM Token refreshed: $newToken');
        onTokenRefreshCallback?.call(newToken);
      });
    } catch (e) {
      debugPrint('[FcmService] Could not retrieve FCM token: $e');
    }
  }

  /// Display a heads-up foreground notification banner when an alert arrives while app is open.
  Future<void> showForegroundNotification(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('notif_push') ?? true)) {
        debugPrint('[FcmService] Suppressed foreground notification because notif_push is disabled.');
        return;
      }
      final type = (message.data['type'] ?? message.data['templateName'] ?? '').toString().toUpperCase();
      if (type.contains('INCIDENT') || type.contains('ALERT')) {
        if (!(prefs.getBool('notif_emergency') ?? true)) return;
      } else if (type.contains('CHECK_IN') || type.contains('REMINDER')) {
        if (!(prefs.getBool('notif_reminders') ?? true)) return;
      }

      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] ?? 'Evenear';
      final body = notification?.body ?? message.data['body'] ?? '';

      final androidDetails = AndroidNotificationDetails(
        notificationChannelId,
        notificationChannelName,
        channelDescription: notificationChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payloadJson = jsonEncode(message.data);

      await _localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payloadJson,
      );
    } catch (e) {
      debugPrint('[FcmService] Error displaying foreground notification: $e');
    }
  }

  /// Trigger a test notification to verify push/local notification pipeline
  Future<bool> sendTestNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      onTokenRefreshCallback?.call(token);
    }
    if (!kIsWeb) {
      try {
        final androidDetails = AndroidNotificationDetails(
          notificationChannelId,
          notificationChannelName,
          channelDescription: notificationChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(body),
        );
        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        await _localNotifications.show(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(
            android: androidDetails,
            iOS: iosDetails,
          ),
          payload: jsonEncode({'type': 'TEST_NOTIFICATION'}),
        );
      } catch (e) {
        debugPrint('[FcmService] Local test notification display note: $e');
      }
    }
    return true;
  }

  /// Process action routing for notifications based on NOTIFICATION.md catalog
  void handleMessageAction(Map<String, dynamic> data) {
    if (_onNotificationTapCallback != null) {
      _onNotificationTapCallback!(data);
    } else {
      debugPrint('[FcmService] Listener not attached yet. Buffering pending notification payload: $data');
      _pendingPayload = data;
    }
  }
}
