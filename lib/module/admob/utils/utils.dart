import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_iap/flutter_iap.dart';

import '../../remote_config/remote_config.dart';
import '../model/ad_config/ad_config.dart';
import 'native_full_util.dart';

AdUnitsConfig get adUnitsConfig =>
    RemoteConfigManager.instance.adsRemoteConfig.adUnitsConfig;

final nativeFullUtil = NativeFullUtil(adConfig: adUnitsConfig.nativeFull);

final nativeFullSplashUtil = NativeFullUtil(
  adConfig: adUnitsConfig.nativeFullSplash,
  adKey: 'native_full_splash',
);

/// Tạo controller native theo [adConfig] — trả [NativeCollapsibleBannerController]
/// khi type là collapsibleBanner, ngược lại [NativeAdController].
/// Nơi giữ kết quả phải khai [AdController].
T createNativeController<T extends AdController>({
  required AdFactory factory,
  required AdUnitConfig adConfig,
  AdUnitConfig? adExpandConfig,
  NativeAdType? type,
  String? adKey,
  bool enableAutoReload = false,
  bool autoRefill = false,
  Map<String, Object>? customOptions,
}) {
  final effectiveType = type ?? adConfig.type;
  if (effectiveType == NativeAdType.collapsibleBanner) {
    return NativeCollapsibleBannerController(
          config: adConfig.nativeBannerConfig,
          autoRefill: autoRefill,
          collapsed: NativeBannerAdId(
            adId: adConfig.id,
            adId2: adConfig.id2,
            adId2RequestPercentage: adConfig.id2RequestPercentage,
            adKey: adKey,
          ),
          expanded: adExpandConfig != null
              ? NativeBannerAdId(
                  adId: adExpandConfig.id,
                  adId2: adExpandConfig.id2,
                  adId2RequestPercentage: adExpandConfig.id2RequestPercentage,
                  adKey: '${adKey}_expand',
                )
              : null,
        )
        as T;
  }
  return NativeAdController(
        factoryId: effectiveType.getAdFactoryId(factory),
        adId: adConfig.id,
        adId2: adConfig.id2,
        adId2RequestPercentage: adConfig.id2RequestPercentage,
        adKey: adKey,
        autoReload: enableAutoReload && adConfig.autoReload,
        autoRefill: autoRefill,
        customOptions: customOptions,
        style: adConfig.style,
      )
      as T;
}

void setEnableAppOpenAd(bool isEnable) {
  if (PurchasesManager.instance.isPremium) {
    isEnable = false;
  }
  MyAds.instance.appLifecycleReactor?.setShouldShow(isEnable);
}

Future<void> preloadInterAd(AdUnitConfig config) async {
  if (!PurchasesManager.instance.isPremium && config.isEnable) {
    await MyAds.instance.preloadInterstitialAd(
      adId: config.id,
      adId2: config.id2,
      adId2RequestPercentage: config.id2RequestPercentage,
      opacity: config.opacity,
    );
  }
}

Future<void> preloadAppOpenAd(AdUnitConfig config) async {
  if (!PurchasesManager.instance.isPremium && config.isEnable) {
    await MyAds.instance.preloadAppOpenAd(
      adId: config.id,
      adId2: config.id2,
      adId2RequestPercentage: config.id2RequestPercentage,
      opacity: config.opacity,
    );
  }
}
