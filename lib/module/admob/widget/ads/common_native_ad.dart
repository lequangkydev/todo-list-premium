import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_iap/flutter_iap.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../src/shared/cubit/ad_visibility_cubit.dart';
import '../../model/ad_config/ad_config.dart';

/// Lớp gốc render native — CHỈ được gọi bên trong `AutoReloadNativeAd`.
class CommonNativeAd extends StatefulWidget {
  const CommonNativeAd({
    super.key,
    this.adConfig,
    this.factory = AdFactory.mediumNativeAd,
    this.offAdMaintainSize = false,
    this.ignoreCubit = false,
    this.hideMaintainSize = false,
    this.placeholderHeight,
    this.customOptions,
    this.customLoading,
  }) : controller = null,
       type = null;

  const CommonNativeAd.control({
    super.key,
    required this.controller,
    this.type,
    this.offAdMaintainSize = false,
    this.ignoreCubit = false,
    this.hideMaintainSize = false,
    this.placeholderHeight,
    this.customLoading,
  }) : adConfig = null,
       factory = AdFactory.mediumNativeAd,
       customOptions = null;

  final AdUnitConfig? adConfig;
  final AdFactory factory;
  final NativeAdController? controller;
  final NativeAdType? type;
  final bool offAdMaintainSize;
  final bool hideMaintainSize;
  final bool ignoreCubit;
  final double? placeholderHeight;
  final Map<String, Object>? customOptions;
  final Widget? customLoading;

  @override
  State<CommonNativeAd> createState() => _CommonNativeAdState();
}

class _CommonNativeAdState extends State<CommonNativeAd> {
  bool isAdEnabled = false;

  @override
  void initState() {
    if (widget.controller != null) {
      isAdEnabled = true;
    } else {
      isAdEnabled = widget.adConfig?.isEnable ?? false;
    }

    super.initState();
  }

  NativeAdType? get _type => widget.type ?? widget.adConfig?.type;

  @override
  Widget build(BuildContext context) {
    if (!isAdEnabled) {
      return SizedBox(
        height: widget.offAdMaintainSize
            ? _type?.calculateAdHeight(widget.placeholderHeight ?? 0)
            : widget.placeholderHeight,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: widget.placeholderHeight ?? 0),
      child: IAPBuilder(
        builder: (context, state, isPremium) {
          if (isPremium) {
            return const SizedBox();
          }
          if (widget.ignoreCubit) {
            return _buildNativeAd();
          }
          final isShow = context.watch<AdVisibilityCubit>().state;
          return Visibility(
            visible: isAdEnabled && isShow,
            maintainState: true,
            maintainAnimation: widget.hideMaintainSize,
            maintainSize: widget.hideMaintainSize,
            child: _buildNativeAd(),
          );
        },
      ),
    );
  }

  Widget _buildNativeAd() {
    if (widget.controller != null) {
      return MyNativeAd.control(
        controller: widget.controller,
        type: widget.type,
        loadingWidget: widget.customLoading,
      );
    }
    final adConfig = widget.adConfig!;
    return MyNativeAd(
      factoryId: adConfig.type.getAdFactoryId(widget.factory),
      adId: adConfig.id,
      adId2: adConfig.id2,
      adId2RequestPercentage: adConfig.id2RequestPercentage,
      type: adConfig.type,
      style: adConfig.style,
      customOptions: widget.customOptions,
      loadingWidget: widget.customLoading,
    );
  }
}
