import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBannerWidget extends StatefulWidget {
  final String? realAdUnitId;

  const AdBannerWidget({super.key, this.realAdUnitId});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // Standard Google AdMob Test Banner IDs for safe testing
    final String testAdUnitId = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ca-app-pub-3940256099942544/2934735716'
        : 'ca-app-pub-3940256099942544/6300978111';

    final String adUnitId = (widget.realAdUnitId != null && widget.realAdUnitId!.contains('/'))
        ? widget.realAdUnitId!
        : testAdUnitId;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.transparent,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
