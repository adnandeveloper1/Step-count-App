import 'package:flutter/foundation.dart';

/// AdMob ad unit ids. Debug and profile builds use Google's test units:
/// tapping your own live ads can get the AdMob account suspended. The
/// matching AdMob app id is set per build type in android/app/build.gradle.kts.
abstract final class AdIds {
  static const _releaseBanner = 'ca-app-pub-2778021395942301/9392185493';
  static const _releaseRewarded = 'ca-app-pub-2778021395942301/4502076037';

  static const _testBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static String get banner => kReleaseMode ? _releaseBanner : _testBanner;
  static String get rewarded => kReleaseMode ? _releaseRewarded : _testRewarded;
}
