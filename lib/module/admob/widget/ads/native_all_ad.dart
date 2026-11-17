import 'package:flutter_ads/ads_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../model/native_all_config/native_all_config.dart';
import '../../utils/native_all_util.dart';
import 'auto_reload_native_ad.dart';

class NativeAllAd extends StatefulWidget {
  const NativeAllAd({
    super.key,
    required this.slot,
    this.type,
    this.padding,
    this.ignoreCubit = false,
    this.hideMaintainSize = false,
    this.ignoreRouteObserver = false,
    this.placeholderHeight,
  });

  /// Enable + type của vị trí
  final NativeSlotEnable slot;

  /// Chốt type lúc tạo controller (mặc định [slot.type])
  final NativeAdType? type;
  final bool hideMaintainSize;
  final EdgeInsetsGeometry? padding;
  final bool ignoreCubit;
  final bool ignoreRouteObserver;
  final double? placeholderHeight;

  @override
  State<NativeAllAd> createState() => _NativeAllAdState();
}

class _NativeAllAdState extends State<NativeAllAd> {
  AdController? controller;
  late final NativeAdType _type = widget.type ?? widget.slot.type;

  @override
  void initState() {
    super.initState();
    if (widget.slot.isEnable) {
      controller = NativeAllUtil.instance.getController(type: _type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutoReloadNativeAd.control(
      controller: controller,
      type: _type,
      visible: controller != null,
      padding: widget.padding,
      ignoreCubit: widget.ignoreCubit,
      hideMaintainSize: widget.hideMaintainSize,
      ignoreRouteObserver: widget.ignoreRouteObserver,
      placeholderHeight: widget.placeholderHeight,
      enableAutoReload: true,
    );
  }

  @override
  void dispose() {
    if (controller != null) {
      NativeAllUtil.instance.disposeController(controller!);
    }
    super.dispose();
  }
}
