// Bought themes, kept on the phone and in the account's Firestore document
// (`purchasedThemes`, `activeTheme`), so a sign-out or reinstall doesn't
// lose themes paid for with coins.

/// Themes everyone owns; they are never saved to the account.
const freeThemeIds = ['default_dark', 'default_light'];

/// [owned] without the free themes.
List<String> paidThemes(List<String> owned) =>
    owned.where((id) => !freeThemeIds.contains(id)).toList();

/// The themes to keep after loading the account [data]: the free ones, the
/// [local] ones and the account's. [active] is the account's equipped theme,
/// or null when it has none or doesn't own it.
({List<String> owned, String? active}) themesFromAccount(
  Map<String, dynamic> data, {
  required List<String> local,
}) {
  final cloud = data['purchasedThemes'];
  final owned = {
    ...freeThemeIds,
    ...local,
    if (cloud is List) ...cloud.whereType<String>(),
  }.toList();
  final active = data['activeTheme'];
  return (
    owned: owned,
    active: active is String && owned.contains(active) ? active : null,
  );
}
