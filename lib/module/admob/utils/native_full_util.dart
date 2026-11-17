import 'dart:async';
import 'dart:math';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_ads/ads_flutter.dart';

import '../../../src/shared/helpers/logger_utils.dart';
import '../../remote_config/remote_config.dart';
import '../model/ad_config/ad_config.dart';

class NativeFullUtil {
  NativeFullUtil({required this.adConfig, this.adKey});

  final NativeFullAdConfig adConfig;
  final String? adKey;

  bool get visible {
    final displayMode =
        RemoteConfigManager.instance.adsRemoteConfig.nativeFullDisplayMode;

    final random = Random().nextInt(2);
    logger.i('Display mode: $displayMode, random: $random');
    return switch (displayMode) {
      0 => false,
      2 => random == 1, // random 0 hoặc 1, là 1 thì hiển thị quảng cáo
      _ => true,
    };
  }

  Future<void> preloadAd() async {
    if (!adConfig.isEnable) {
      return;
    }
    return MyAds.instance.preloadNativeInterstitialAd(
      adId: adConfig.id,
      adId2: adConfig.id2,
      adId2RequestPercentage: adConfig.id2RequestPercentage,
      adKey: adKey,
      autoRefill: false,
    );
  }

  Future<void> show({VoidCallback? onClose}) async {
    if (adConfig.isEnable && visible) {
      await MyAds.instance.showNativeInterstitialAd(
        adId: adConfig.id,
        adId2: adConfig.id2,
        adId2RequestPercentage: adConfig.id2RequestPercentage,
        config: adConfig.nativeInterstitialConfig,
        displayMode: NativeAdDisplayMode.overlay,
        forceShow: true,
        adKey: adKey,
        adDismissed: onClose,
        onFailed: onClose,
        autoReload: adConfig.autoReload,
      );
    } else {
      onClose?.call();
    }
  }
}
