import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_iap/flutter_iap.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../src/shared/cubit/ad_visibility_cubit.dart';

/// Bọc [NativeCollapsibleBanner] của thư viện (native collapsible banner).
class CustomNativeBannerAd extends StatelessWidget {
  const CustomNativeBannerAd.control({
    super.key,
    this.controller,
    this.offAdMaintainSize = false,
    this.ignoreCubit = false,
    this.hideMaintainSize = false,
    this.placeholderHeight,
    this.customLoading,
  });

  final NativeCollapsibleBannerController? controller;
  final bool offAdMaintainSize;
  final bool ignoreCubit;
  final bool hideMaintainSize;
  final double? placeholderHeight;
  final Widget? customLoading;

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return SizedBox(height: offAdMaintainSize ? placeholderHeight : 0);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: placeholderHeight ?? 0),
      child: IAPBuilder(
        builder: (context, state, isPremium) {
          if (isPremium) {
            return const SizedBox();
          }
          final child = NativeCollapsibleBanner.control(
            controller: controller!,
            loadingWidget: customLoading,
          );
          if (ignoreCubit) {
            return child;
          }
          final isShow = context.watch<AdVisibilityCubit>().state;
          return Visibility(
            visible: isShow,
            maintainState: true,
            maintainAnimation: hideMaintainSize,
            maintainSize: hideMaintainSize,
            child: child,
          );
        },
      ),
    );
  }
}
