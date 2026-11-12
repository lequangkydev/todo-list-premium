import 'package:flutter/material.dart';
import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import '../../../../module/admob/widget/ads/auto_reload_native_ad.dart';
import '../../../../module/remote_config/remote_config.dart';
import '../../../gen/assets.gen.dart';
import '../../../shared/extension/context_extension.dart';
import '../../../shared/widgets/custom_fade_in_image.dart';
import '../onboarding_screen.dart';
import '../utils/onboarding_controller.dart';

class ContentPageWidget extends StatefulWidget {
  const ContentPageWidget({
    super.key,
    required this.image,
    this.fullImage,
    required this.title,
    required this.description,
    this.adController,
    required this.index,
    this.titleStyle,
    this.descriptionStyle,
    this.onInit,
    required this.type,
  });

  final AssetGenImage image;
  final AssetGenImage? fullImage;
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
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: CustomFadeInImage(
                  image: widget.image.provider(),
                  fit: BoxFit.cover,
                ),
              ),
              buildDescription(),
              24.verticalSpace,
              PageAction(
                activeIndex: widget.index,
                onNextTap: () => context
                    .read<OnboardingController>()
                    .pressNextButton(widget.index),
              ),
            ],
          ),
        ),
        _buildAds(),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style:
                widget.titleStyle ??
                TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w700),
          ),
          Text(
            widget.description,
            textAlign: TextAlign.center,
            style: widget.descriptionStyle ?? TextStyle(fontSize: 17.sp),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
