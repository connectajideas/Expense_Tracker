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
        case 'onSmsReceived':
          final payload = call.arguments as String?;
          if (payload != null && payload.isNotEmpty) {
            _payloadController.add(payload);
          }
          break;
      }
    });
  }

  /// Checks if SMS permissions are granted
  Future<bool> isPermissionGranted() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// Requests SMS and notification permissions from user
  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    // Also request notification permission on Android 13+
    await Permission.notification.request();
    return status.isGranted;
  }

  /// Checks if the app was opened by tapping an SMS debit notification
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
      final hasPerm = await isPermissionGranted();
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
