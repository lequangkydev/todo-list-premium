import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../module/admob/widget/ads/auto_reload_native_ad.dart';
import '../../../../module/remote_config/remote_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../gen/assets.gen.dart';
import '../../../shared/extension/context_extension.dart';
import '../onboarding_screen.dart';
import '../utils/onboarding_controller.dart';
import 'onboarding_illustration.dart';

class ContentPageWidget extends StatefulWidget {
  const ContentPageWidget({
    super.key,
    required this.scene,
    required this.title,
    required this.description,
    this.adController,
    required this.index,
    this.titleStyle,
    this.descriptionStyle,
    this.onInit,
    required this.type,
  });

  final OnboardingScene scene;
  final String title;
  final TextStyle? titleStyle;
  final String description;
  final TextStyle? descriptionStyle;
  final AdController? adController;
  final int index;
  final VoidCallback? onInit;
  final NativeAdType type;

  @override
  State<ContentPageWidget> createState() => _ContentPageWidgetState();
}

class _ContentPageWidgetState extends State<ContentPageWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();
    widget.onInit?.call();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: OnboardingIllustration(scene: widget.scene)),
                buildDescription(),
                const SizedBox(height: AppSpace.xl),
                PageAction(
                  activeIndex: widget.index,
                  onNextTap: () => context
                      .read<OnboardingController>()
                      .pressNextButton(widget.index),
                ),
                const SizedBox(height: AppSpace.lg),
              ],
            ),
          ),
          _buildAds(),
        ],
      ),
    );
  }

  Widget _buildAds() {
    if (widget.adController != null) {
      return AutoReloadNativeAd.control(
        key: ValueKey(widget.adController?.adKey),
        controller: widget.adController,
        type: widget.type,
        ignoreRouteObserver: true,
        padding: MyAds.instance.isFullAds
            ? EdgeInsets.zero
            : const EdgeInsets.only(top: 10).h,
      );
    } else if (RemoteConfigManager
            .instance
            .appConfig
            .screenFlow
            .enableSwipeIntro &&
        MyAds.instance.isFullAds &&
        widget.index < context.read<OnboardingController>().totalPage - 1) {
      return Transform.flip(
        flipX: context.isRTL,
        child: Container(
          height: 140.h,
          alignment: Alignment.center,
          child: Lottie.asset(Assets.lottie.slideLeft.path, height: 80.h),
        ),
      );
    }
    return 60.verticalSpace;
  }

  Widget buildDescription() {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            header: true,
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: widget.titleStyle ?? text.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            widget.description,
            textAlign: TextAlign.center,
            style:
                widget.descriptionStyle ??
                text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: context.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
