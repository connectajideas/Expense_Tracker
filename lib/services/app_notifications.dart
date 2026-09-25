import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final tapStream = StreamController<String>.broadcast();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) tapStream.add(response.payload!);
      },
    );
  }

  /// Returns the payload if the app was launched by tapping a notification (cold start).
  static Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  static Future<void> show({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) async {
    const details = AndroidNotificationDetails(
      'expense_tracker_channel',
      'Expense Tracker',
      channelDescription: 'Budget and auto-capture alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: details),
      payload: payload,
    );
  }
}
