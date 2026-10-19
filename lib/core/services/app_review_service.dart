import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows Google Play's in-app review pop-up once the user has used the app
/// enough, and opens the Play Store listing from the "Rate Us" tile.
///
/// Play limits how often the pop-up really appears and never says whether it
/// did, so we only track when we last asked.
class AppReviewService {
  AppReviewService({
    Box? box,
    InAppReview? inAppReview,
    DateTime Function()? clock,
    bool Function()? isAppInForeground,
    Future<bool> Function(Uri url)? openUrl,
  }) : _boxOverride = box,
       _inAppReview = inAppReview ?? InAppReview.instance,
       _clock = clock ?? DateTime.now,
       _isAppInForeground =
           isAppInForeground ??
           (() =>
               WidgetsBinding.instance.lifecycleState ==
               AppLifecycleState.resumed),
       _openUrl =
           openUrl ??
           ((url) => launchUrl(url, mode: LaunchMode.externalApplication));

  static const String boxName = 'buildUpData';
  static const String launchCountKey = 'reviewLaunchCount';
  static const String firstOpenKey = 'reviewFirstOpenMs';
  static const String lastAskedKey = 'reviewLastAskedMs';

  static const int minLaunches = 5;
  static const Duration minInstallAge = Duration(days: 3);
  static const Duration askAgainAfter = Duration(days: 30);

  static final Uri playStoreUrl = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.nexappra.buildup',
  );

  // Shared by every instance so two screens can't ask at the same time.
  static bool _requestInFlight = false;
  static bool _storeOpenInFlight = false;

  final Box? _boxOverride;
  final InAppReview _inAppReview;
  final DateTime Function() _clock;
  final bool Function() _isAppInForeground;
  final Future<bool> Function(Uri url) _openUrl;

  Box get _box => _boxOverride ?? Hive.box(boxName);

  int? _readInt(String key) {
    final value = _box.get(key);
    return value is int ? value : null;
  }

  /// Call once per app start.
  void recordLaunch() {
    final now = _clock().millisecondsSinceEpoch;
    final firstOpen = _readInt(firstOpenKey);
    // Missing, corrupt, or in the future (clock moved back): start again from now.
    if (firstOpen == null || firstOpen > now) _box.put(firstOpenKey, now);
    _box.put(launchCountKey, (_readInt(launchCountKey) ?? 0) + 1);
  }

  /// Whether the user has used the app enough and wasn't asked recently.
  bool get isDue {
    final now = _clock().millisecondsSinceEpoch;
    final launches = _readInt(launchCountKey) ?? 0;
    var firstOpen = _readInt(firstOpenKey);
    var lastAsked = _readInt(lastAskedKey);

    // A date in the future means the clock moved back; restart the wait from now
    // instead of blocking the prompt until the clock catches up.
    if (firstOpen != null && firstOpen > now) {
      _box.put(firstOpenKey, now);
      firstOpen = now;
    }
    if (lastAsked != null && lastAsked > now) {
      _box.put(lastAskedKey, now);
      lastAsked = now;
    }

    if (launches < minLaunches) return false;
    if (firstOpen == null || now - firstOpen < minInstallAge.inMilliseconds) {
      return false;
    }
    if (lastAsked != null && now - lastAsked < askAgainAfter.inMilliseconds) {
      return false;
    }
    return true;
  }

  /// Shows the review pop-up if the user qualifies. Safe to call often.
  ///
  /// Returns true if the pop-up was requested from Play.
  Future<bool> maybeRequestReview() async {
    if (_requestInFlight || !isDue) return false;
    _requestInFlight = true;
    try {
      if (!await _inAppReview.isAvailable()) return false;
      // Re-check after the await: the app may have gone to the background
      // (or a permission dialog opened) while Play answered.
      if (!_isAppInForeground() || !isDue) return false;
      _box.put(lastAskedKey, _clock().millisecondsSinceEpoch);
      await _inAppReview.requestReview();
      return true;
    } catch (e) {
      debugPrint('In-app review failed: $e');
      return false;
    } finally {
      _requestInFlight = false;
    }
  }

  /// Opens the Play Store listing, falling back to the web page if the Play
  /// Store app can't be opened. Returns false if neither worked.
  Future<bool> openStoreListing() async {
    if (_storeOpenInFlight) return true;
    _storeOpenInFlight = true;
    try {
      await _inAppReview.openStoreListing();
      return true;
    } catch (e) {
      debugPrint('Play Store listing failed, trying web: $e');
      try {
        return await _openUrl(playStoreUrl);
      } catch (e) {
        debugPrint('Play Store web page failed: $e');
        return false;
      }
    } finally {
      _storeOpenInFlight = false;
    }
  }

  @visibleForTesting
  static void resetInFlightForTest() {
    _requestInFlight = false;
    _storeOpenInFlight = false;
  }
}
