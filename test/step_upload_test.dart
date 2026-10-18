import 'package:build_up/core/utils/step_upload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('needsStepUpload', () {
    test('the first update since the app started is sent', () {
      expect(
        needsStepUpload(
          todaySteps: 120,
          today: '2026-10-18',
          sent: null,
          minNewSteps: 500,
        ),
        isTrue,
      );
    });

    test('fewer new steps than asked for wait', () {
      expect(
        needsStepUpload(
          todaySteps: 3400,
          today: '2026-10-18',
          sent: (day: '2026-10-18', steps: 3000),
          minNewSteps: 500,
        ),
        isFalse,
      );
    });

    test('enough new steps are sent', () {
      expect(
        needsStepUpload(
          todaySteps: 3500,
          today: '2026-10-18',
          sent: (day: '2026-10-18', steps: 3000),
          minNewSteps: 500,
        ),
        isTrue,
      );
    });

    test('nothing new is not sent again', () {
      expect(
        needsStepUpload(
          todaySteps: 3000,
          today: '2026-10-18',
          sent: (day: '2026-10-18', steps: 3000),
          minNewSteps: 1,
        ),
        isFalse,
      );
    });

    test(
      'after midnight today is sent even though yesterday had more steps',
      () {
        // Yesterday ended at 12,000; today's 600 steps must still go out.
        expect(
          needsStepUpload(
            todaySteps: 600,
            today: '2026-10-19',
            sent: (day: '2026-10-18', steps: 12000),
            minNewSteps: 500,
          ),
          isTrue,
        );
      },
    );

    test('the first update of a new day is sent with no steps yet', () {
      // It also carries yesterday's final total.
      expect(
        needsStepUpload(
          todaySteps: 0,
          today: '2026-10-19',
          sent: (day: '2026-10-18', steps: 12000),
          minNewSteps: 1,
        ),
        isTrue,
      );
    });
  });
}
