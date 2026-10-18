import 'dart:io';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box box;
  final storage = LocalStorageService();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_weekly_steps_test');
    Hive.init(dir.path);
    box = await Hive.openBox('buildUpData');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('a new week drops the days the phone never synced', () {
    // Last used Wednesday 14 Oct 2026, then not until Tuesday 20 Oct.
    box.put('weeklySteps', '8000,9000,12000,0,0,0,0');
    storage.saveDailyHistory({
      '2026-10-12': 8000,
      '2026-10-13': 9000,
      '2026-10-14': 12000,
    });

    storage.startNewDay('2026-10-20');

    expect(storage.getWeeklySteps(), '0,0,0,0,0,0,0');
  });

  test('a new day keeps the days of this week', () {
    box.put('weeklySteps', '8000,9000,0,0,0,0,0');
    storage.saveDailyHistory({'2026-10-12': 8000, '2026-10-13': 9000});

    storage.startNewDay('2026-10-14');

    expect(storage.getWeeklySteps(), '8000,9000,0,0,0,0,0');
  });

  test('refreshWeeklySteps rebuilds the week from the history', () {
    box.put('weeklySteps', '0,0,0,0,0,0,11000');
    storage.saveDailyHistory({'2026-10-18': 11000, '2026-10-19': 2500});

    final week = storage.refreshWeeklySteps(DateTime(2026, 10, 19, 9));

    expect(week, [2500, 0, 0, 0, 0, 0, 0]);
    expect(storage.getWeeklySteps(), '2500,0,0,0,0,0,0');
  });
}
