import 'dart:io';
import 'package:build_up/core/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box box;
  final storage = LocalStorageService();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_history_test');
    Hive.init(dir.path);
    box = await Hive.openBox('buildUpData');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('is empty before anything is saved', () {
    expect(storage.getDailyHistory(), isEmpty);
  });

  test('saves and loads the history', () {
    storage.saveDailyHistory({'2026-10-11': 10420, '2026-10-12': 300});

    expect(storage.getDailyHistory(), {'2026-10-11': 10420, '2026-10-12': 300});
  });

  test('returns empty instead of throwing on corrupt data', () async {
    await box.put('dailyHistory', 'not json');

    expect(storage.getDailyHistory(), isEmpty);
  });

  test('skips entries that are not numbers', () async {
    await box.put('dailyHistory', '{"2026-10-11": 5, "2026-10-12": "x"}');

    expect(storage.getDailyHistory(), {'2026-10-11': 5});
  });
}
