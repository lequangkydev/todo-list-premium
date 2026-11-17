import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../module/admob/model/ad_config/ad_config.dart';
import '../../../module/admob/utils/utils.dart';
import '../../../module/remote_config/remote_config.dart';
import '../../../module/tracking_screen/screen_logger.dart';
import '../../config/theme/app_theme.dart';
import '../../shared/extension/context_extension.dart';
import 'utils/intro_ad_util.dart';
import 'utils/onboarding_controller.dart';
import 'widgets/indicator.dart';
import 'widgets/onboarding_illustration.dart';
import 'widgets/page_widget.dart';

part 'widgets/page_action.dart';

@RoutePage()
class OnBoardingScreen extends StatefulWidget implements AutoRouteWrapper {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    final controller = OnboardingController();
    return RepositoryProvider(create: (context) => controller, child: this);
  }
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  bool get enableSwipeIntro =>
      RemoteConfigManager.instance.appConfig.screenFlow.enableSwipeIntro ||
      !MyAds.instance.isFullAds;

  late final OnboardingController onboardingController = context
      .read<OnboardingController>();

  bool isClickAds = false;

  @override
  void initState() {
    super.initState();
    if (RemoteConfigManager.instance.enableAllAds) {
      listenClickAdEvent();
    }
    IntroAdUtil.instance.initNativeAd();
    AnalyticLogger.instance.logScreen('Intro1Screen');
  }

  void listenClickAdEvent() {
    if (!MyAds.instance.isFullAds) {
      return;
    }
    IntroAdUtil.instance.listenClickAdEvent(
      onAdClicked: (isLastAd) {
        if (isLastAd) {
          onboardingController.goToNextScreen();
        } else {
          onboardingController.swipeToNextPage();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: onboardingController.pageController,
        physics: enableSwipeIntro
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        children: <Widget>[
          ContentPageWidget(
            scene: OnboardingScene.today,
            title: context.l10n.onbTitle1,
            description: context.l10n.onbDesc1,
            index: 0,
            adController: IntroAdUtil.instance.nativeController1,
            type: adUnitsConfig.nativeIntro1.type,
            onInit: () {
              AnalyticLogger.instance.logScreen('Intro1Screen');
              IntroAdUtil.instance.nativeController2?.load();
            },
          ),
          ContentPageWidget(
            scene: OnboardingScene.quickAdd,
            title: context.l10n.onbTitle2,
            description: context.l10n.onbDesc2,
            index: 1,
            adController: IntroAdUtil.instance.nativeController2,
            type: adUnitsConfig.nativeIntro2.type,
            onInit: () {
              AnalyticLogger.instance.logScreen('Intro2Screen');
              if (IntroAdUtil.instance.nativeController2Full != null) {
                IntroAdUtil.instance.nativeController2Full?.preloadAd();
              } else {
                IntroAdUtil.instance.nativeController3?.preloadAd();
              }
            },
          ),
          if (IntroAdUtil.instance.nativeController2Full != null)
            _NativeFull(
              key: const ValueKey(2),
              controller: IntroAdUtil.instance.nativeController2Full!,
              onInit: () => IntroAdUtil.instance.nativeController3?.preloadAd(),
              onClose: onboardingController.swipeToNextPage,
              onFailed: () {
                setState(() {
                  IntroAdUtil.instance.nativeController2Full = null;
                });
              },
            ),
          ContentPageWidget(
            scene: OnboardingScene.reminder,
            title: context.l10n.onbTitle3,
            description: context.l10n.onbDesc3,
            index: 2,
            adController: IntroAdUtil.instance.nativeController3,
            type: adUnitsConfig.nativeIntro3.type,
            onInit: () {
              AnalyticLogger.instance.logScreen('Intro3Screen');
              if (IntroAdUtil.instance.nativeController3Full != null) {
                IntroAdUtil.instance.nativeController3Full?.preloadAd();
              } else {
                IntroAdUtil.instance.nativeController4?.preloadAd();
              }
            },
          ),
          if (IntroAdUtil.instance.nativeController3Full != null)
            _NativeFull(
              key: const ValueKey(3),
              controller: IntroAdUtil.instance.nativeController3Full!,
              onInit: () => IntroAdUtil.instance.nativeController4?.preloadAd(),
              onClose: onboardingController.swipeToNextPage,
              onFailed: () {
                setState(() {
                  IntroAdUtil.instance.nativeController3Full = null;
                });
              },
            ),
          ContentPageWidget(
            scene: OnboardingScene.privacy,
            title: context.l10n.onbTitle4,
            description: context.l10n.onbDesc4,
            index: 3,
            adController: IntroAdUtil.instance.nativeController4,
            type: adUnitsConfig.nativeIntro4.type,
            onInit: () {
              AnalyticLogger.instance.logScreen('Intro4Screen');
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    onboardingController.dispose();
    IntroAdUtil.instance.disposeAds();
    super.dispose();
  }
}

class _NativeFull extends StatefulWidget {
  const _NativeFull({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onFailed,
    required this.onInit,
  });

  final NativeInterstitialAdController controller;

  /// Ad đóng (dismiss) → sang trang tiếp
  final VoidCallback onClose;

  /// Ad lỗi → gỡ controller native full
  final VoidCallback onFailed;
  final VoidCallback onInit;

  @override
  State<_NativeFull> createState() => _NativeFullState();
}

class _NativeFullState extends State<_NativeFull>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NativeInterstitialAdView.control(
      controller: widget.controller,
      onDismissed: widget.onClose,
      loadingWidget: FullScreenAdLoading.instance.buildLoadingContent(),
      onFailed: () => Future.delayed(Duration.zero, widget.onFailed),
    );
  }
}
