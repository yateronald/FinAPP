import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';

/// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('FCM Background message received: ${message.messageId}');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Android notification channel id — MUST match the backend's
  /// `FCM_CHANNEL_ID` and the manifest `default_notification_channel_id`.
  static const String channelId = 'fynexa_alerts';
  static const String _channelName = 'Fynexa Alerts';
  static const String _channelDesc = 'Budget alerts, AI insights and account activity';

  // NOTE: this MUST stay a lazy getter. As an eagerly-initialised field it runs
  // when the singleton is constructed — before Firebase.initializeApp() — and
  // throws `[core/no-app] No Firebase App '[DEFAULT]' has been created`, which
  // silently disabled all push notifications.
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Initialize Firebase & Local Notification Plugin
  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp();

      // 2. Set Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 4. Initialize Local Notifications Plugin with App Logo Icon
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifs.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          _handleNotificationTap(response.payload);
        },
      );

      // 5. Create Android High Priority Notification Channel
      if (Platform.isAndroid) {
        const androidChannel = AndroidNotificationChannel(
          channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          showBadge: true,
        );

        await _localNotifs
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);
      }

      // 3. Request Permissions (iOS + Android 13+). Done AFTER the local-
      //    notifications plugin is initialized so the Android request works.
      await _requestPermissions();

      // 6. Setup Foreground Listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      // 7. Setup Tap Handlers (App opened from background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageTap(message);
      });

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      // 8. Re-register the token whenever FCM rotates it, so the backend never
      //    holds a stale token (a common cause of silently-lost pushes).
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((token) {
        _sendTokenToBackend(token);
      });

      _initialized = true;
      if (kDebugMode) {
        print('NotificationService initialized successfully with @mipmap/ic_launcher');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService initialization error: $e');
      }
    }
  }

  /// Fetch the current FCM token and register it with the backend.
  /// Called after login and on every token refresh.
  Future<void> registerDeviceToken() async {
    try {
      // On iOS the APNS token must be available before requesting an FCM token.
      if (Platform.isIOS) {
        final apns = await _fcm.getAPNSToken();
        if (apns == null) return; // not ready yet; onTokenRefresh will catch up
      }
      final token = await _fcm.getToken();
      if (token != null) await _sendTokenToBackend(token);
    } catch (e) {
      if (kDebugMode) print('Failed to obtain FCM token: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiClient.instance.post('/notifications/fcm-token', body: {
        'token': token,
        'deviceType': Platform.isAndroid ? 'android' : 'ios',
      });
      if (kDebugMode) print('Registered FCM token with backend.');
    } catch (e) {
      if (kDebugMode) print('Failed to register FCM token with backend: $e');
    }
  }

  /// Turn push ON: ensure the OS permission is granted, then register the
  /// device token. Returns false if the user declined the permission (so the
  /// caller can keep the setting off and prompt them to enable it in Settings).
  Future<bool> enableAndRegister() async {
    await init();
    final granted = await ensurePermission();
    if (!granted) return false;
    await registerDeviceToken();
    return true;
  }

  /// Whether the OS notification permission is currently granted, requesting it
  /// if it hasn't been decided yet.
  Future<bool> ensurePermission() async {
    final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
    if (Platform.isAndroid) {
      final android = _localNotifs.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final requested = await android?.requestNotificationsPermission() ?? false;
      final enabled = await android?.areNotificationsEnabled() ?? false;
      return requested || enabled;
    }
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Turn push OFF: remove this device's token from the backend and delete it
  /// from Firebase so no further messages are delivered to this device.
  Future<void> unregister() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await ApiClient.instance.post('/notifications/fcm-token/remove', body: {
          'token': token,
          'deviceType': Platform.isAndroid ? 'android' : 'ios',
        });
      }
    } catch (e) {
      if (kDebugMode) print('Failed to unregister token from backend: $e');
    }
    try {
      await _fcm.deleteToken(); // fully unregister from FCM
      if (kDebugMode) print('Deleted FCM token (push disabled).');
    } catch (e) {
      if (kDebugMode) print('Failed to delete FCM token: $e');
    }
  }

  Future<void> _requestPermissions() async {
    // Firebase-level permission (drives the iOS prompt; also the Android 13+
    // POST_NOTIFICATIONS prompt on recent plugin versions).
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (kDebugMode) {
      print('Notification permission: ${settings.authorizationStatus}');
    }

    // Android 13+ (API 33): explicitly request POST_NOTIFICATIONS via the local
    // notifications plugin so the system dialog reliably appears the first time.
    if (Platform.isAndroid) {
      final granted = await _localNotifs
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      if (kDebugMode) print('Android POST_NOTIFICATIONS granted: $granted');
    }
  }

  /// Display a heads-up local notification banner with app logo when message arrives in foreground
  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_stat_notification', // monochrome status-bar icon (not a white box)
      color: const Color(0xFF6366F1), // brand accent on icon/title
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // colored logo
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        contentTitle: notification.title,
      ),
      playSound: true,
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

    _localNotifs.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
      payload: message.data['type'] ?? '',
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    final type = message.data['type'] ?? '';
    _handleNotificationTap(type);
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (kDebugMode) {
      print('Notification tapped with payload/type: $payload');
    }
    // Navigation logic handled dynamically via Router/Ref if app is active
  }
}
