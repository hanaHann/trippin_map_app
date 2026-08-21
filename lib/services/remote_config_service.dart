import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Wraps Firebase Remote Config for the map screen's banner ad unit ID, so
/// it can be swapped from the Firebase Console without shipping a new app
/// build. Every method here is defensive: if Firebase hasn't been set up yet
/// (no google-services.json / GoogleService-Info.plist) or the device has no
/// network, [init] and [mapBannerAdUnitId] fall back to the hardcoded
/// default instead of crashing app startup or the ad widget.
class RemoteConfigService {
  RemoteConfigService._();

  static const String mapBannerAdUnitIdKey = 'map_banner_ad_unit_id';
  static const String mapBannerAdUnitIdDefault =
      'ca-app-pub-3229282743833938/9392844633';

  static FirebaseRemoteConfig? _instance;

  static Future<void> init() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults({
        mapBannerAdUnitIdKey: mapBannerAdUnitIdDefault,
      });
      await remoteConfig.fetchAndActivate();
      _instance = remoteConfig;
    } catch (_) {
      _instance = null;
    }
  }

  static String get mapBannerAdUnitId {
    try {
      final value = _instance?.getString(mapBannerAdUnitIdKey);
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {}
    return mapBannerAdUnitIdDefault;
  }
}
