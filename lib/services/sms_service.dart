import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'upi_parser.dart';

class SmsService {
  SmsService._();
  static final instance = SmsService._();

  static const _channel = MethodChannel('com.example.expensy/sms');
  final _payloadController = StreamController<String>.broadcast();

  Stream<String> get onPayloadReceived => _payloadController.stream;

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onNotificationTapped':
        case 'onPaymentDetected':
        case 'onSmsReceived':
          final payload = call.arguments as String?;
          if (payload != null && payload.isNotEmpty) {
            _payloadController.add(payload);
          }
          break;
      }
    });
  }

  /// Checks if Notification Listener Service (special access for GPay/PhonePe) is enabled
  Future<bool> isNotificationListenerGranted() async {
    try {
      final granted = await _channel.invokeMethod<bool>('isNotificationListenerGranted');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android Settings to let user enable Expensy in "Notification access"
  Future<void> openNotificationListenerSettings() async {
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } catch (_) {}
  }

  /// Checks if SMS permission is granted
  Future<bool> isSmsGranted() async {
    return await Permission.sms.isGranted;
  }

  /// Requests SMS permission
  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Checks if normal notifications (POST_NOTIFICATIONS) are enabled
  Future<bool> isNotificationPermissionGranted() async {
    return await Permission.notification.isGranted;
  }

  /// Request normal notifications permission (Android 13+)
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Checks if both SMS and notification permissions are granted (legacy method)
  Future<bool> isPermissionGranted() async {
    final smsStatus = await Permission.sms.status;
    final notifStatus = await Permission.notification.status;
    return smsStatus.isGranted && notifStatus.isGranted;
  }

  /// Requests SMS and notification permissions (legacy method)
  Future<bool> requestPermission() async {
    final notifStatus = await Permission.notification.request();
    final smsStatus = await Permission.sms.request();
    return smsStatus.isGranted && notifStatus.isGranted;
  }

  /// Checks if the app was opened by tapping an auto-capture notification
  Future<String?> getLaunchPayload() async {
    try {
      final payload = await _channel.invokeMethod<String>('getLaunchPayload');
      return payload;
    } catch (_) {
      return null;
    }
  }

  /// Scans the last 50 SMS messages in the inbox and returns parsed debit transactions
  Future<List<ParsedUpiPayment>> scanRecentSms() async {
    try {
      final hasPerm = await isSmsGranted();
      if (!hasPerm) return [];

      final rawList = await _channel.invokeListMethod<Map>('readRecentSms');
      if (rawList == null) return [];

      final List<ParsedUpiPayment> results = [];
      for (final item in rawList) {
        final body = item['body'] as String? ?? '';
        final dateEpoch = item['date'] as int?;
        final date = dateEpoch != null
            ? DateTime.fromMillisecondsSinceEpoch(dateEpoch)
            : null;

        final parsed = parseTransactionText(body, date: date);
        if (parsed != null) {
          results.add(parsed);
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }
}
