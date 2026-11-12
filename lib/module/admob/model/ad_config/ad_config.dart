import 'package:flutter_ads/ads_flutter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../remote_config/remote_config.dart';

part 'ad_config.freezed.dart';
part 'ad_config.g.dart';

@JsonSerializable(explicitToJson: true)
class AdUnitConfig {
  const AdUnitConfig({
    this.id = '',
    this.id2 = '',
    this.enableFullAds = true,
    this.enableNormal = true,
    this.typeFullAds = NativeAdType.adaptive,
    this.typeNormal = NativeAdType.adaptive,
    this.autoReload = true,
    this.id2RequestPercentage = 100,
    this.opacity = 1,
    this.extraKeys,
    this.style,
    this.nativeBannerConfig = const NativeCollapsibleBannerConfig(),
  });

  factory AdUnitConfig.fromJson(Map<String, dynamic> json) =>
      _$AdUnitConfigFromJson(json);

  final String id;
  final String id2;

  /// Bật ad khi full-ads
  final bool enableFullAds;

  /// Bật ad khi normal
  final bool enableNormal;

  /// Loại native khi full-ads
  @NativeAdTypeConverter()
  final NativeAdType typeFullAds;

  /// Loại native khi normal
  @NativeAdTypeConverter()
  final NativeAdType typeNormal;
  final bool autoReload;
  final double id2RequestPercentage;
  final int opacity;
  final Map<String, dynamic>? extraKeys;

  /// Style riêng của ad (merge trên nền `MyAds.defaultNativeStyle`)
  final NativeAdStyle? style;
  final NativeCollapsibleBannerConfig nativeBannerConfig;

  Map<String, dynamic> toJson() => _$AdUnitConfigToJson(this);
}

extension AdUnitConfigExtension on AdUnitConfig {
  bool get isEnable =>
      RemoteConfigManager.instance.enableAllAds &&
      (MyAds.instance.isFullAds ? enableFullAds : enableNormal);

  /// Type hiệu lực theo state — màn hình dùng `adConfig.type`, KHÔNG tự check isFullAds.
  NativeAdType get type => MyAds.instance.isFullAds ? typeFullAds : typeNormal;

  /// Ad NEO ĐÁY màn (render như `bottomNavigationBar`): collapsibleBanner HOẶC large.
  bool get isBottomAd =>
      type == NativeAdType.collapsibleBanner || type == NativeAdType.large;
}

@JsonSerializable(explicitToJson: true)
class NativeFullAdConfig extends AdUnitConfig {
  const NativeFullAdConfig({
    super.id,
    super.id2,
    super.enableFullAds,
    super.enableNormal,
    super.autoReload,
    super.id2RequestPercentage,
    super.opacity,
    super.extraKeys,
    this.nativeInterstitialConfig = const NativeInterstitialConfig(
      openStoreCorner: NativeAdCorner.topRight,
      closeCorner: NativeAdCorner.topLeft,
      showOpenStore: false,
      xCountdown: true,
      countdownSeconds: 1,
      xClickToClose: false,
      xAdClickPercent: 50,
      xAdClickPercentMeta: 50,
      clickToPass: true,
    ),
    this.nativeAppOpenConfig = const NativeAppOpenConfig(
      countdownSeconds: 2,
      clickToPass: true,
      xClickToClose: false,
    ),
  });

  factory NativeFullAdConfig.fromJson(Map<String, dynamic> json) =>
      _$NativeFullAdConfigFromJson(json);

  final NativeInterstitialConfig nativeInterstitialConfig;
  final NativeAppOpenConfig nativeAppOpenConfig;

  @override
  Map<String, dynamic> toJson() => _$NativeFullAdConfigToJson(this);
}

@freezed
abstract class AdUnitsConfig with _$AdUnitsConfig {
  @JsonSerializable(explicitToJson: true)
  const factory AdUnitsConfig({
    @Default(AdUnitConfig()) AdUnitConfig openOnResume,
    @Default(NativeFullAdConfig(enableFullAds: false, enableNormal: false))
    NativeFullAdConfig nativeResume,
    @Default(AdUnitConfig()) AdUnitConfig interSplash,
    @Default(AdUnitConfig()) AdUnitConfig openSplash,
    @Default(
      AdUnitConfig(
        enableFullAds: false,
        enableNormal: false,
        typeFullAds: NativeAdType.banner,
        typeNormal: NativeAdType.banner,
      ),
    )
    AdUnitConfig nativeSplash,
    @Default(AdUnitConfig()) AdUnitConfig bannerAll,
    @Default(AdUnitConfig()) AdUnitConfig nativeBanner,
    @Default(AdUnitConfig()) AdUnitConfig nativeBannerExpand,
    @Default(AdUnitConfig()) AdUnitConfig nativeLanguage,
    @Default(AdUnitConfig()) AdUnitConfig nativeLanguageSelect,
    @Default(AdUnitConfig()) AdUnitConfig nativeIntro1,
    @Default(AdUnitConfig(enableFullAds: false, enableNormal: false))
    AdUnitConfig nativeIntro2,
    @Default(NativeFullAdConfig(enableNormal: false))
    NativeFullAdConfig nativeFullIntro2,
    @Default(AdUnitConfig(enableFullAds: false)) AdUnitConfig nativeIntro3,
    @Default(NativeFullAdConfig(enableNormal: false))
    NativeFullAdConfig nativeFullIntro3,
    @Default(AdUnitConfig(enableNormal: false)) AdUnitConfig nativeIntro4,
    @Default(AdUnitConfig(enableNormal: false)) AdUnitConfig interIntro,
    @Default(AdUnitConfig(enableNormal: false)) AdUnitConfig nativePermission,
    @Default(AdUnitConfig(enableNormal: false))
    AdUnitConfig nativePermissionStorage,
    @Default(NativeFullAdConfig(enableNormal: false))
    NativeFullAdConfig nativeFull,
    @Default(NativeFullAdConfig(enableNormal: false))
    NativeFullAdConfig nativeFullSplash,
    @Default(AdUnitConfig()) AdUnitConfig interSplashUninstall,
    @Default(AdUnitConfig(enableNormal: false)) AdUnitConfig interUninstall,
    @Default(AdUnitConfig(enableNormal: false)) AdUnitConfig nativeUninstall,
    @Default(AdUnitConfig(enableNormal: false)) AdUnitConfig nativeExit,
    @Default(AdUnitConfig()) AdUnitConfig interAll,
  }) = _AdUnitsConfig;

  factory AdUnitsConfig.fromJson(Map<String, dynamic> json) =>
      _$AdUnitsConfigFromJson(json);
}

@freezed
abstract class AdsRemoteConfig with _$AdsRemoteConfig {
  @JsonSerializable(explicitToJson: true)
  const factory AdsRemoteConfig({
    @Default(AdUnitsConfig()) AdUnitsConfig adUnitsConfig,
    @Default(true) bool showAllAds,
    @Default(1) int nativeFullDisplayMode,
    @Default(15) int interInterval,
    @Default(10) int nativeInterval,
    @Default(24) int buttonXSize,
    @Default(0) int id2RequestTimeout,
    @Default(7) int cbFetchInterval,
    @Default(false) bool reloadNativeAdWhenClicked,
    @Default(false) bool keepMetaAd,
    @Default(NativeAdStyle()) NativeAdStyle defaultNativeStyle,
  }) = _AdsRemoteConfig;

  factory AdsRemoteConfig.fromJson(Map<String, dynamic> json) =>
      _$AdsRemoteConfigFromJson(json);
}
