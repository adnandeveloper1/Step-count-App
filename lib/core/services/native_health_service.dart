import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nativeHealthProvider = Provider<NativeHealthService>((ref) {
  return NativeHealthService();
});

class NativeHealthService {
  static const platform = MethodChannel('com.buildup.app/health_services');

  Future<int> getHardwareSteps() async {
    try {final int steps = await platform.invokeMethod('getHardwareSteps');
    return steps;
    } on PlatformException catch (e) {
      // Add this line to see the actual error in Logcat while app is closed
      print("DEBUG_TRACKER: Native bridge error: ${e.message}");
      return 0;
    }
  }

}