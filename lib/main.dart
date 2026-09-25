import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'screens/add_expense_screen.dart';
import 'services/app_notifications.dart';
import 'services/sms_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppNotifications.init();
  SmsService.instance.init();

  // Ask for POST_NOTIFICATIONS (Android 13+) up front, regardless of
  // whether the user ever flips the SMS Auto-Capture switch.
  await Permission.notification.request();

  runApp(const MyApp());
}
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<String>? _tapSub;
  StreamSubscription<String>? _smsSub;

  @override
  void initState() {
    super.initState();
    _tapSub = AppNotifications.tapStream.stream.listen(_openPrefilled);
    _smsSub = SmsService.instance.onPayloadReceived.listen(_openPrefilled);
    _checkColdStartLaunch();
  }

  Future<void> _checkColdStartLaunch() async {
    // Check both local notifications launch and SMS native launch payload
    String? payload = await AppNotifications.getLaunchPayload();
    payload ??= await SmsService.instance.getLaunchPayload();

    if (payload != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPrefilled(payload!),
      );
    }
  }

  void _openPrefilled(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(
            prefillAmount: (data['amount'] as num).toDouble(),
            prefillMerchant: data['merchant'] as String,
          ),
        ),
      );
    } catch (_) {
      // Malformed payload, ignore.
    }
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    _smsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Expense Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
