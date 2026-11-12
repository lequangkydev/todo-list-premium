import 'package:flutter_ads/ads_flutter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'native_all_config.freezed.dart';
part 'native_all_config.g.dart';

@freezed
abstract class NativeAllConfig with _$NativeAllConfig {
  const NativeAllConfig._();

  const factory NativeAllConfig({
    @Default(NativeSlotEnable()) NativeSlotEnable nativeLanguageSetting,
    @Default(NativeSlotEnable()) NativeSlotEnable nativeWifiDevices,
    @Default(NativeSlotEnable()) NativeSlotEnable nativeIrDevices,
    @Default(NativeSlotEnable()) NativeSlotEnable nativeSaveRemote,
    @Default(NativeSlotEnable()) NativeSlotEnable nativeHistory,
  }) = _NativeAllConfig;

  factory NativeAllConfig.fromJson(Map<String, dynamic> json) =>
      _$NativeAllConfigFromJson(json);

  List<NativeSlotEnable> get allSlots => [
    nativeLanguageSetting,
    nativeWifiDevices,
    nativeIrDevices,
    nativeSaveRemote,
    nativeHistory,
  ];
}

/// Bật/tắt 1 slot native theo state — thay `bool` đơn.
@freezed
abstract class NativeSlotEnable with _$NativeSlotEnable {
  const NativeSlotEnable._();

  const factory NativeSlotEnable({
    @Default(true) bool enableFullAds,
    @Default(true) bool enableNormal,
    @NativeAdTypeConverter()
    @Default(NativeAdType.collapsibleBanner)
    NativeAdType typeFullAds,
    @NativeAdTypeConverter()
    @Default(NativeAdType.medium)
    NativeAdType typeNormal,
  }) = _NativeSlotEnable;

  factory NativeSlotEnable.fromJson(Map<String, dynamic> json) =>
      _$NativeSlotEnableFromJson(json);

  bool get isEnable => MyAds.instance.isFullAds ? enableFullAds : enableNormal;

  NativeAdType get type => MyAds.instance.isFullAds ? typeFullAds : typeNormal;
}
