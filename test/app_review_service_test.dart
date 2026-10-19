import 'dart:async';
import 'dart:io';

import 'package:build_up/core/services/app_review_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:in_app_review/in_app_review.dart';

class FakeInAppReview implements InAppReview {
  bool available = true;
  Object? listingError;
  int requestCount = 0;
  int listingCount = 0;
  Completer<bool>? availableGate;

  @override
  Future<bool> isAvailable() =>
      availableGate?.future ?? Future.value(available);

  @override
  Future<void> requestReview() async => requestCount++;

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {
    listingCount++;
    if (listingError != null) throw listingError!;
  }
}

void main() {
  late Directory dir;
  late Box box;
  late FakeInAppReview review;
  late DateTime now;
  late bool foreground;
  late List<Uri> openedUrls;
  late bool urlOpens;

  AppReviewService service() => AppReviewService(
    box: box,
    inAppReview: review,
    clock: () => now,
    isAppInForeground: () => foreground,
    openUrl: (url) async {
      openedUrls.add(url);
      return urlOpens;
    },
  );

  /// Five launches, then jump past the 3-day install age.
  void makeDue() {
    for (var i = 0; i < AppReviewService.minLaunches; i++) {
      service().recordLaunch();
    }
    now = now.add(AppReviewService.minInstallAge);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('review_test');
    Hive.init(dir.path);
    box = await Hive.openBox('review_${DateTime.now().microsecondsSinceEpoch}');
    review = FakeInAppReview();
    now = DateTime(2026, 1, 1, 12);
    foreground = true;
    openedUrls = [];
    urlOpens = true;
    AppReviewService.resetInFlightForTest();
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('when to ask', () {
    test('not due on a fresh install', () {
      expect(service().isDue, isFalse);
    });

    test('not due with 4 launches even after 3 days', () {
      for (var i = 0; i < 4; i++) {
        service().recordLaunch();
      }
      now = now.add(const Duration(days: 10));
      expect(service().isDue, isFalse);
    });

    test('not due with 5 launches before 3 days', () {
      for (var i = 0; i < 5; i++) {
        service().recordLaunch();
      }
      now = now.add(const Duration(days: 2, hours: 23));
      expect(service().isDue, isFalse);
    });

    test('due with 5 launches at exactly 3 days', () {
      makeDue();
      expect(service().isDue, isTrue);
    });

    test('first open date is kept across launches', () {
      service().recordLaunch();
      final first = box.get(AppReviewService.firstOpenKey);
      now = now.add(const Duration(days: 1));
      service().recordLaunch();
      expect(box.get(AppReviewService.firstOpenKey), first);
    });
  });

  group('asking', () {
    test('asks once, then waits 30 days', () async {
      makeDue();
      expect(await service().maybeRequestReview(), isTrue);
      expect(review.requestCount, 1);

      now = now.add(const Duration(days: 29, hours: 23));
      expect(await service().maybeRequestReview(), isFalse);

      now = now.add(const Duration(hours: 1));
      expect(await service().maybeRequestReview(), isTrue);
      expect(review.requestCount, 2);
    });

    test('does nothing when not due', () async {
      expect(await service().maybeRequestReview(), isFalse);
      expect(review.requestCount, 0);
    });

    test(
      'Play not available: does not ask and does not use up the 30 days',
      () async {
        makeDue();
        review.available = false;
        expect(await service().maybeRequestReview(), isFalse);
        expect(box.get(AppReviewService.lastAskedKey), isNull);
      },
    );

    test(
      'app in background: does not ask and does not use up the 30 days',
      () async {
        makeDue();
        foreground = false;
        expect(await service().maybeRequestReview(), isFalse);
        expect(review.requestCount, 0);
        expect(box.get(AppReviewService.lastAskedKey), isNull);

        foreground = true;
        expect(await service().maybeRequestReview(), isTrue);
      },
    );

    test(
      'app goes to background while Play is checking: does not ask',
      () async {
        makeDue();
        review.availableGate = Completer<bool>();
        final pending = service().maybeRequestReview();
        foreground = false;
        review.availableGate!.complete(true);
        expect(await pending, isFalse);
        expect(review.requestCount, 0);
      },
    );

    test('isAvailable throwing is caught', () async {
      makeDue();
      review.availableGate = Completer<bool>()
        ..completeError(Exception('no play'));
      expect(await service().maybeRequestReview(), isFalse);
    });
  });

  group('races', () {
    test(
      'two calls at once (e.g. home screen rebuilt) ask only once',
      () async {
        makeDue();
        review.availableGate = Completer<bool>();
        final first = service().maybeRequestReview();
        final second = service().maybeRequestReview();
        review.availableGate!.complete(true);
        expect(await Future.wait([first, second]), [true, false]);
        expect(review.requestCount, 1);
      },
    );

    test(
      'after an overlapping call finishes, the next call respects the 30 days',
      () async {
        makeDue();
        await service().maybeRequestReview();
        expect(await service().maybeRequestReview(), isFalse);
        expect(review.requestCount, 1);
      },
    );

    test('double tap on Rate Us opens the Store once', () async {
      final results = await Future.wait([
        service().openStoreListing(),
        service().openStoreListing(),
      ]);
      expect(results, [true, true]);
      expect(review.listingCount, 1);
    });
  });

  group('bad stored data and clock changes', () {
    test('corrupt stored values do not crash', () async {
      box.put(AppReviewService.launchCountKey, 'oops');
      box.put(AppReviewService.firstOpenKey, 1.5);
      box.put(AppReviewService.lastAskedKey, 'x');
      expect(service().isDue, isFalse);
      service().recordLaunch();
      expect(box.get(AppReviewService.launchCountKey), 1);
      expect(
        box.get(AppReviewService.firstOpenKey),
        now.millisecondsSinceEpoch,
      );
    });

    test(
      'clock moved back before first open: install age restarts from now',
      () {
        service().recordLaunch();
        now = now.subtract(const Duration(days: 365));
        service().recordLaunch();
        expect(
          box.get(AppReviewService.firstOpenKey),
          now.millisecondsSinceEpoch,
        );
      },
    );

    test(
      'clock moved back after asking: waits 30 days from now, not a year',
      () async {
        makeDue();
        await service().maybeRequestReview();
        now = now.subtract(const Duration(days: 365));
        expect(service().isDue, isFalse);
        now = now.add(AppReviewService.askAgainAfter);
        expect(service().isDue, isTrue);
      },
    );
  });

  group('Rate Us', () {
    test('opens the Play Store app', () async {
      expect(await service().openStoreListing(), isTrue);
      expect(review.listingCount, 1);
      expect(openedUrls, isEmpty);
    });

    test('falls back to the web page when the Play Store app fails', () async {
      review.listingError = Exception('no play store');
      expect(await service().openStoreListing(), isTrue);
      expect(openedUrls, [AppReviewService.playStoreUrl]);
    });

    test(
      'returns false when both fail so the screen can show an error',
      () async {
        review.listingError = Exception('no play store');
        urlOpens = false;
        expect(await service().openStoreListing(), isFalse);
      },
    );
  });
}
