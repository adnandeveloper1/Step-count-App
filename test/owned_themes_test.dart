import 'package:build_up/features/shop/models/owned_themes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('themesFromAccount', () {
    test('themes bought on the account come back after a reinstall', () {
      final themes = themesFromAccount({
        'purchasedThemes': ['ocean_wave', 'midnight_gold'],
        'activeTheme': 'midnight_gold',
      }, local: const []);

      expect(
        themes.owned,
        containsAll([
          'default_dark',
          'default_light',
          'ocean_wave',
          'midnight_gold',
        ]),
      );
      expect(themes.active, 'midnight_gold');
    });

    test('themes already on the phone are kept', () {
      final themes = themesFromAccount(
        {
          'purchasedThemes': ['ocean_wave'],
        },
        local: const ['default_dark', 'default_light', 'sunset_glow'],
      );

      expect(themes.owned, containsAll(['ocean_wave', 'sunset_glow']));
      expect(themes.owned.toSet().length, themes.owned.length);
    });

    test('an account without themes owns the free ones', () {
      final themes = themesFromAccount({}, local: const []);

      expect(themes.owned, ['default_dark', 'default_light']);
      expect(themes.active, isNull);
    });

    test('an equipped theme that is not owned is not restored', () {
      final themes = themesFromAccount({
        'activeTheme': 'cyberpunk_neon',
      }, local: const []);

      expect(themes.active, isNull);
    });

    test('unknown values in the account are ignored', () {
      final themes = themesFromAccount({
        'purchasedThemes': 'ocean_wave',
        'activeTheme': 7,
      }, local: const []);

      expect(themes.owned, ['default_dark', 'default_light']);
      expect(themes.active, isNull);
    });
  });

  group('paidThemes', () {
    test('leaves out the free themes', () {
      expect(paidThemes(['default_dark', 'ocean_wave', 'default_light']), [
        'ocean_wave',
      ]);
    });
  });
}
