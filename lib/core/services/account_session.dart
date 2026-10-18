/// Numbers the signed-in sessions on this device.
///
/// Work that awaits (e.g. a 30 s sensor read) captures [current] first and
/// drops its result if the number changed meanwhile, so a signed-out
/// account's steps and coins are never written after sign-out. Riverpod's
/// `ref.mounted` is not enough: it stays true after `invalidate` until the
/// provider rebuilds.
class AccountSession {
  static int _current = 0;

  static int get current => _current;

  /// Call at sign-out, before clearing local data.
  static void end() => _current++;

  /// True while the account's data is being deleted. Syncs that start
  /// meanwhile (the step poll, a background task's request) must not write
  /// the profile back, which would also republish the public Step Race card.
  static bool deleting = false;
}
