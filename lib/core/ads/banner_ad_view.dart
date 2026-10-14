import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// A full-width banner at most [maxHeight] tall, sized to the ad that loads
/// so no empty space shows around it. Takes no space until an ad has
/// loaded, so a failed load leaves no gap.
class BannerAdView extends StatefulWidget {
  /// Tallest ad allowed, in logical pixels.
  final int maxHeight;

  const BannerAdView({super.key, this.maxHeight = 60});

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
  AdSize? _size;
  int? _loadedWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The adaptive size depends on the width: reload on rotation.
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width != _loadedWidth) _load(width);
  }

  void _load(int width) {
    _loadedWidth = width;
    _ad?.dispose();
    _size = null;
    _ad = BannerAd(
      adUnitId: AdIds.banner,
      // Google picks the ad; its real size is only known once loaded.
      size: AdSize.getInlineAdaptiveBannerAdSize(width, widget.maxHeight),
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          final size = await (ad as BannerAd).getPlatformAdSize();
          if (!mounted || ad != _ad || size == null) return;
          setState(() => _size = size);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (ad == _ad) _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final size = _size;
    if (ad == null || size == null) return const SizedBox.shrink();
    return SizedBox(
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
