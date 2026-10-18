// Whether the data saved on the phone belongs to the signed-in account.
// Until it does, nothing may be synced to Firestore: a fresh install has 0
// coins and steps, and writing those would overwrite the account's real ones.

enum LocalDataState {
  /// Saved for this account.
  ready,

  /// Saved by an app version that did not store the owner: it is the
  /// signed-in account's, so it is kept and marked as theirs.
  adopt,

  /// Nothing saved (a fresh install or after sign-out) or another account's
  /// data: the account must be loaded from Firebase first.
  restore,
}

LocalDataState localDataState({
  required String? owner,
  required String uid,
  required bool hasLocalData,
}) {
  if (owner == uid) return LocalDataState.ready;
  if (owner == null && hasLocalData) return LocalDataState.adopt;
  return LocalDataState.restore;
}
