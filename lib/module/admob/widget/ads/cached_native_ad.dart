import 'package:flutter/material.dart';
import 'package:flutter_ads/ads_flutter.dart';

import '../../model/ad_config/ad_config.dart';
import '../../utils/native_ad_util.dart';
import 'auto_reload_native_ad.dart';

class CachedNativeAd extends StatefulWidget {
  const CachedNativeAd({
    super.key,
    this.visible = true,
    this.padding,
    this.ignoreCubit = false,
    this.hideMaintainSize = false,
    required this.nativeAdUtil,
    this.type,
    this.enableAutoReload = false,
    this.placeholderHeight,
  });

  final CachedNativeAdUtil nativeAdUtil;
  final bool visible;
  final bool hideMaintainSize;
  final EdgeInsetsGeometry? padding;
  final bool ignoreCubit;
  final NativeAdType? type;
  final bool enableAutoReload;
  final double? placeholderHeight;

  @override
  State<CachedNativeAd> createState() => _CachedNativeAdState();
}

class _CachedNativeAdState extends State<CachedNativeAd> {
  AdController? controller;

  @override
  void initState() {
    if (widget.visible) {
      controller = widget.nativeAdUtil.getController();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AutoReloadNativeAd.control(
      controller: controller,
      type: widget.type ?? widget.nativeAdUtil.adConfig.type,
      visible: controller != null,
      padding: widget.padding,
      ignoreCubit: widget.ignoreCubit,
      hideMaintainSize: widget.hideMaintainSize,
      placeholderHeight: widget.placeholderHeight,
      enableAutoReload: widget.enableAutoReload,
    );
  }

  @override
  void dispose() {
    if (controller != null) {
      widget.nativeAdUtil.disposeController(controller!);
    }
    super.dispose();
  }
}
