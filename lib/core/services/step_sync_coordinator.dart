import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// What a background task did about a step sync.
enum BackgroundSyncOutcome {
  /// No app was running, so the background task saved the steps itself.
  ranHere,

  /// The running app took the sync; the background task left storage alone.
  delegatedToApp,

  /// Another background task was saving; this one did nothing.
  skippedBusy,
}

/// Keeps a single writer for the step data in local storage.
///
/// Hive caches the box per isolate, so two isolates writing the same box lose
/// each other's writes and can corrupt the file. The app's isolate and the
/// WorkManager background task can both run in the same process. Whoever
/// writes storage holds one port name here: the app for as long as it runs,
/// a background task only while it saves. Anyone else asks the holder:
///
/// - `sync`: the app answers `accepted` and syncs itself; a background owner
///   answers `busy`.
/// - `release`: the holder answers `alive`, and a background owner later sends
///   `released` once it is done.
///
/// A holder that does not answer within the ping timeout is treated as dead
/// (its isolate stopped without releasing) and replaced.
class StepSyncCoordinator {
  static const _portName = 'buildup_step_storage';

  /// App side, before opening storage. Waits for a background task that is
  /// saving, then holds storage until [AppStorageClaim.dispose]. While held,
  /// background tasks hand their sync to [sync].
  static Future<AppStorageClaim> claimForApp(
    Future<void> Function() sync, {
    Duration pingTimeout = const Duration(seconds: 1),
  }) async {
    final port = ReceivePort();
    while (!IsolateNameServer.registerPortWithName(port.sendPort, _portName)) {
      await _waitForRelease(pingTimeout);
    }

    Future<void>? inFlight;
    port.listen((message) {
      final [kind as String, reply as SendPort] = message as List;
      if (kind == 'release') {
        reply.send('alive');
        return;
      }
      // Accept before syncing: the sensor read can take up to 30 s, and the
      // background task must not time out and write in the meantime.
      reply.send('accepted');
      // Requests that arrive during a sync join it.
      if (inFlight != null) return;
      // Yield before calling sync so inFlight is set before it can complete,
      // even when sync throws synchronously.
      inFlight = Future(() async {
        try {
          await sync();
        } catch (e) {
          debugPrint('Step sync requested by background task failed: $e');
        } finally {
          inFlight = null;
        }
      });
    });
    return AppStorageClaim._(port);
  }

  /// Background side, before the slow sensor read: true when a running app
  /// accepted the sync, so there is nothing left to do.
  static Future<bool> delegateToApp({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final holder = IsolateNameServer.lookupPortByName(_portName);
    if (holder == null) return false;
    return await _ask(holder, 'sync', timeout) == 'accepted';
  }

  /// Background side, after the sensor read. Runs [work] while holding
  /// storage, unless the app is running (it syncs instead) or another
  /// background task is saving.
  static Future<BackgroundSyncOutcome> runInBackground(
    Future<void> Function() work, {
    Duration pingTimeout = const Duration(seconds: 2),
  }) async {
    final port = ReceivePort();
    for (var attempt = 0; attempt < 3; attempt++) {
      if (IsolateNameServer.registerPortWithName(port.sendPort, _portName)) {
        return _runAsOwner(port, work);
      }
      final holder = IsolateNameServer.lookupPortByName(_portName);
      if (holder == null) continue;
      switch (await _ask(holder, 'sync', pingTimeout)) {
        case 'accepted':
          port.close();
          return BackgroundSyncOutcome.delegatedToApp;
        case 'busy':
          port.close();
          return BackgroundSyncOutcome.skippedBusy;
        default:
          _removeIfStill(holder);
      }
    }
    port.close();
    return BackgroundSyncOutcome.skippedBusy;
  }

  static Future<BackgroundSyncOutcome> _runAsOwner(
    ReceivePort port,
    Future<void> Function() work,
  ) async {
    final waiters = <SendPort>[];
    port.listen((message) {
      final [kind as String, reply as SendPort] = message as List;
      if (kind == 'sync') {
        reply.send('busy');
      } else {
        reply.send('alive');
        waiters.add(reply);
      }
    });
    try {
      await work();
      return BackgroundSyncOutcome.ranHere;
    } finally {
      _removeIfStill(port.sendPort);
      for (final waiter in waiters) {
        waiter.send('released');
      }
      port.close();
    }
  }

  /// Returns when the current holder released storage or turned out dead.
  static Future<void> _waitForRelease(Duration pingTimeout) async {
    final holder = IsolateNameServer.lookupPortByName(_portName);
    if (holder == null) return;

    final reply = ReceivePort();
    final answers = StreamIterator(reply);
    try {
      holder.send(['release', reply.sendPort]);
      final answered = await answers.moveNext().timeout(
        pingTimeout,
        onTimeout: () => false,
      );
      if (!answered) {
        _removeIfStill(holder);
        return;
      }
      // Alive: wait for the release, re-checking now and then in case the
      // holder dies before sending it.
      await answers.moveNext().timeout(pingTimeout * 5, onTimeout: () => false);
    } finally {
      await answers.cancel();
      reply.close();
    }
  }

  static Future<String?> _ask(
    SendPort holder,
    String kind,
    Duration timeout,
  ) async {
    final reply = ReceivePort();
    try {
      holder.send([kind, reply.sendPort]);
      return await reply.first.timeout(timeout, onTimeout: () => null)
          as String?;
    } finally {
      reply.close();
    }
  }

  /// Removes the registration only if [port] still holds it, so a newer
  /// holder that replaced it is left in place.
  static void _removeIfStill(SendPort port) {
    if (IsolateNameServer.lookupPortByName(_portName) == port) {
      IsolateNameServer.removePortNameMapping(_portName);
    }
  }

  /// Removes any registration. Tests only.
  static void clearForTest() {
    IsolateNameServer.removePortNameMapping(_portName);
  }
}

/// The app's hold on storage, from [StepSyncCoordinator.claimForApp].
class AppStorageClaim {
  final ReceivePort _port;

  AppStorageClaim._(this._port);

  void dispose() {
    StepSyncCoordinator._removeIfStill(_port.sendPort);
    _port.close();
  }
}
