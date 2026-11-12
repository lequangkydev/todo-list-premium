import 'package:flutter/cupertino.dart';
import 'package:flutter_ads/ads_flutter.dart';

import '../../../../module/admob/model/ad_config/ad_config.dart';
import '../../../../module/admob/utils/utils.dart';

class IntroAdUtil {
  IntroAdUtil._();

  static IntroAdUtil instance = IntroAdUtil._();

  AdController? nativeController1;
  AdController? nativeController2;
  NativeInterstitialAdController? nativeController2Full;
  AdController? nativeController3;
  NativeInterstitialAdController? nativeController3Full;
  AdController? nativeController4;

  void listenClickAdEvent({required ValueChanged<bool> onAdClicked}) {
    final nativeControllers = [
      nativeController1,
      nativeController2,
      nativeController3,
      nativeController4,
    ];
    for (final controller in nativeControllers) {
      controller?.onAdClicked = (ad) {
        onAdClicked(controller == nativeController4);
      };
    }
  }

  AdController? _createController({
    required AdUnitConfig config,
    required String adKey,
  }) {
    if (config.isEnable) {
      return createNativeController(
        factory: AdFactory.bottomNativeAd,
        adConfig: config,
        adKey: adKey,
      );
    }
    return null;
  }

  NativeInterstitialAdController? _createFullController({
    required NativeFullAdConfig config,
    required String adKey,
  }) {
    if (config.isEnable) {
      return NativeInterstitialAdController(
        adId: config.id,
        adId2: config.id2,
        adId2RequestPercentage: config.id2RequestPercentage,
        adKey: adKey,
        config: config.nativeInterstitialConfig,
        autoReload: config.autoReload,
      );
    }
    return null;
  }

  void initNativeAd() {
    nativeController2 = _createController(
      config: adUnitsConfig.nativeIntro2,
      adKey: 'native_intro2',
    );

    nativeController2Full = _createFullController(
      config: adUnitsConfig.nativeFullIntro2,
      adKey: 'native_intro2_full',
    );

    nativeController3 = _createController(
      config: adUnitsConfig.nativeIntro3,
      adKey: 'native_intro3',
    );

    nativeController3Full = _createFullController(
      config: adUnitsConfig.nativeFullIntro3,
      adKey: 'native_intro3_full',
    );

    nativeController4 = _createController(
      config: adUnitsConfig.nativeIntro4,
      adKey: 'native_intro4',
    );
  }

  void preloadAd1() {
    if (nativeController1 == null) {
      nativeController1 = _createController(
        config: adUnitsConfig.nativeIntro1,
        adKey: 'native_intro1',
      );
      nativeController1?.load();
    }
  }

  void disposeAds() {
    nativeController1?.dispose();
    nativeController2?.dispose();
    nativeController2Full?.dispose();
    nativeController3?.dispose();
    nativeController3Full?.dispose();
    nativeController4?.dispose();

    nativeController1 = null;
    nativeController2 = null;
    nativeController2Full = null;
    nativeController3 = null;
    nativeController3Full = null;
    nativeController4 = null;
  }
}

extension AdControllerExtension on AdController {
  Future<void> preloadAd() async {
    if (!status.isLoading && !status.isShowOnScreen) {
      await load();
    }
  }
}
