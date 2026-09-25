import 'dart:async';
import 'sms_service.dart';

/// Legacy alias / wrapper connecting to SmsService
class UpiListener {
  UpiListener._();
  static final instance = UpiListener._();

  Future<bool> isPermissionGranted() => SmsService.instance.isPermissionGranted();

  Future<bool> requestPermission() => SmsService.instance.requestPermission();

  void start() {
    SmsService.instance.init();
  }

  void stop() {
    // SMS broadcast receiver is registered in AndroidManifest
  }
}
