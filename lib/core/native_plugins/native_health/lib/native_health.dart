import 'package:flutter/services.dart';

class NativeHealth {
  static const MethodChannel _channel = MethodChannel('com.buildup.app/health_services');

  static Future<int> getHardwareSteps() async {
    try {
      final int? steps = await _channel.invokeMethod<int>('getHardwareSteps');
      return steps ?? -1;
    } on PlatformException catch (_) {
      return -1;
    }
  }

  static Future<int> getAndroidApiLevel() async {
    try {
      final int? level = await _channel.invokeMethod<int>('getAndroidApiLevel');
      return level ?? 0;
    } on PlatformException catch (_) {
      return 0;
    }
  }
}
