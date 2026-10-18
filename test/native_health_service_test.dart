import 'package:build_up/core/services/native_health_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Object? Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(
        NativeHealthService.platform,
        (call) async => handler(call),
      );

  tearDown(
    () =>
        messenger.setMockMethodCallHandler(NativeHealthService.platform, null),
  );

  group('getRecordedSteps', () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final midnight = DateTime(yesterday.year, yesterday.month, yesterday.day);

    test('asks for the whole of a past day in 1-minute buckets', () async {
      MethodCall? asked;
      answer((call) {
        asked = call;
        return {'since': 0, 'buckets': <Object?>[]};
      });
      await NativeHealthService().getRecordedSteps(midnight);
      expect(asked!.method, 'getRecordedSteps');
      expect(asked!.arguments, {
        'startMs': midnight.millisecondsSinceEpoch,
        'endMs': DateTime(
          midnight.year,
          midnight.month,
          midnight.day + 1,
        ).millisecondsSinceEpoch,
        'bucketMinutes': 1,
      });
    });

    test('reads the minutes and when recording began', () async {
      final at = midnight.add(const Duration(hours: 9));
      answer(
        (_) => {
          'since': midnight.millisecondsSinceEpoch,
          'buckets': [
            [at.millisecondsSinceEpoch, 80],
          ],
        },
      );
      final recorded = await NativeHealthService().getRecordedSteps(midnight);
      expect(recorded!.since, midnight);
      expect(recorded.minutes, [(at, 80)]);
    });

    test('skips malformed buckets', () async {
      answer(
        (_) => {
          'since': 0,
          'buckets': [
            'oops',
            [1, 'two'],
            [60000, 5],
          ],
        },
      );
      final recorded = await NativeHealthService().getRecordedSteps(midnight);
      expect(recorded!.minutes.map((m) => m.$2), [5]);
    });

    test('a malformed answer reads as no recording', () async {
      answer((_) => {'since': 'yesterday'});
      expect(await NativeHealthService().getRecordedSteps(midnight), isNull);
    });

    test('no subscription reads as no recording', () async {
      answer((_) => null);
      expect(await NativeHealthService().getRecordedSteps(midnight), isNull);
    });

    test('a platform error reads as no recording', () async {
      answer((_) => throw PlatformException(code: 'boom'));
      expect(await NativeHealthService().getRecordedSteps(midnight), isNull);
    });

    test('no plugin reads as no recording', () async {
      expect(await NativeHealthService().getRecordedSteps(midnight), isNull);
    });

    test('a day that has not started yet asks for nothing', () async {
      var asked = false;
      answer((_) {
        asked = true;
        return null;
      });
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(await NativeHealthService().getRecordedSteps(tomorrow), isNull);
      expect(asked, isFalse);
    });
  });

  group('startStepRecording', () {
    test('passes on whether it subscribed', () async {
      answer((call) => call.method == 'startStepRecording');
      expect(await NativeHealthService().startStepRecording(), isTrue);
    });

    test('is false on a platform error or without the plugin', () async {
      answer((_) => throw PlatformException(code: 'boom'));
      expect(await NativeHealthService().startStepRecording(), isFalse);
      messenger.setMockMethodCallHandler(NativeHealthService.platform, null);
      expect(await NativeHealthService().startStepRecording(), isFalse);
    });
  });
}
