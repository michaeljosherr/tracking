import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:my_flutter_app/models/mock_data.dart';

/// Encodes an in-app [Alert] as a notification payload so we can deep-link
/// into the correct screen when the user taps the notification.
String _payloadFor(Alert alert) {
  return alert.isHub
      ? 'hub:${alert.trackerId}'
      : 'tracker:${alert.trackerId}';
}

/// Singleton wrapper around `flutter_local_notifications` so the rest of the
/// app only needs to call [showAlert].
class NotificationsService {
  NotificationsService._();

  static final NotificationsService instance = NotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _hubChannelId = 'hub_alerts';
  static const _hubChannelName = 'Hub alerts';
  static const _hubChannelDesc =
      'Hub connection events (detected, reconnected, disconnected).';

  static const _trackerChannelId = 'tracker_alerts';
  static const _trackerChannelName = 'Tracker alerts';
  static const _trackerChannelDesc =
      'Tracker status events (out-of-range, disconnected, reconnected).';

  bool _initialized = false;
  int _idCounter = 1000;

  /// Payload of the notification that launched the app from terminated state,
  /// if any. Main app can consume this once the router is ready.
  String? _pendingLaunchPayload;

  /// Callback invoked on tap while the app is running (foreground/background).
  ValueChanged<String?>? _onTap;

  /// Initialize the plugin, create channels, and request permissions.
  /// [onTap] is fired when the user taps a notification while the app is
  /// already running or gets foregrounded by a tap.
  Future<void> initialize({ValueChanged<String?>? onTap}) async {
    _onTap = onTap;
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _onTap?.call(response.payload);
      },
    );

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _hubChannelId,
          _hubChannelName,
          description: _hubChannelDesc,
          importance: Importance.high,
        ),
      );
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _trackerChannelId,
          _trackerChannelName,
          description: _trackerChannelDesc,
          importance: Importance.defaultImportance,
        ),
      );

      try {
        await androidImpl?.requestNotificationsPermission();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[NotificationsService] requestNotificationsPermission: $e');
        }
      }
    }

    // Capture the notification that launched the app (if any) so we can
    // consume it after the router is ready.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _pendingLaunchPayload = launch?.notificationResponse?.payload;
      }
    } catch (_) {}

    _initialized = true;
  }

  /// Returns (and clears) the payload that launched the app from terminated
  /// state, if any.
  String? consumePendingLaunchPayload() {
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return payload;
  }

  /// Update the tap callback after initialize (e.g., once router is ready).
  set onTap(ValueChanged<String?>? cb) => _onTap = cb;

  /// Show a local notification for [alert].
  Future<void> showAlert(Alert alert) async {
    if (!_initialized) return;

    final isHub = alert.isHub;
    final channelId = isHub ? _hubChannelId : _trackerChannelId;
    final channelName = isHub ? _hubChannelName : _trackerChannelName;
    final channelDesc = isHub ? _hubChannelDesc : _trackerChannelDesc;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.status,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(alert.message),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    try {
      await _plugin.show(
        _idCounter++,
        alert.trackerName,
        alert.message,
        details,
        payload: _payloadFor(alert),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationsService] show error: $e');
      }
    }
  }
}
