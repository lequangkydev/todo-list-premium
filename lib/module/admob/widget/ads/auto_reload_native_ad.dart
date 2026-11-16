import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ads/ads_flutter.dart';

import '../../../remote_config/remote_config.dart';
import '../../model/ad_config/ad_config.dart';
import '../../utils/reload_timer_util.dart';
import '../../utils/utils.dart';
import 'common_native_ad.dart';
import 'native_banner_ad.dart';

/// Widget render native DUY NHẤT dùng ở màn hình — thêm auto-reload,
/// nhánh collapsible banner và pause/resume theo điều hướng.
class AutoReloadNativeAd extends StatefulWidget {
  const AutoReloadNativeAd({
    super.key,
    required AdUnitConfig this.adConfig,
    this.expandedAdConfig,
    this.factory = AdFactory.mediumNativeAd,
    this.visible = true,
    this.enableAutoReload = false,
    this.ignoreRouteObserver = false,
    this.padding,
    this.offAdMaintainSize = false,
    this.hideMaintainSize = false,
    this.ignoreCubit = false,
    this.placeholderHeight,
    this.customLoading,
    this.customOptions,
    this.adKey,
  }) : controller = null,
       type = null;

  const AutoReloadNativeAd.control({
    super.key,
    required this.controller,
    required this.type,
    this.visible = true,
    this.enableAutoReload = false,
    this.ignoreRouteObserver = false,
    this.padding,
    this.offAdMaintainSize = false,
    this.hideMaintainSize = false,
    this.ignoreCubit = false,
    this.placeholderHeight,
    this.customLoading,
    this.adKey,
  }) : adConfig = null,
       expandedAdConfig = null,
       factory = AdFactory.mediumNativeAd,
       customOptions = null;

  final AdUnitConfig? adConfig;
  final AdUnitConfig? expandedAdConfig;
  final AdFactory factory;
  final AdController? controller;
  final NativeAdType? type;
  final bool visible;
  final bool enableAutoReload;
  final bool ignoreRouteObserver;
  final EdgeInsetsGeometry? padding;
  final bool offAdMaintainSize;
  final bool hideMaintainSize;
  final bool ignoreCubit;
  final double? placeholderHeight;
  final Widget? customLoading;
  final Map<String, Object>? customOptions;
  final String? adKey;

  @override
  State<AutoReloadNativeAd> createState() => _AutoReloadNativeAdState();
}

class _AutoReloadNativeAdState extends State<AutoReloadNativeAd>
    with AutoRouteAware {
  AdController? controller;
  late bool visible;
  ReloadTimerService? reloadTimerService;
  AppLifecycleListener? appLifecycleListener;
  StreamSubscription<AdStatus>? _statusSubscription;
  AutoRouteObserver? _observer;
  bool isPaused = false;
  bool isCurrentScreen = true;

  /// Tạo bằng constructor mặc định (tự tạo + dispose controller) — ngược lại
  /// là `.control` (controller do nơi khác quản, có thể null khi chưa có ad)
  bool get _ownsController => widget.adConfig != null;

  NativeAdType? get _type => widget.type ?? widget.adConfig?.type;

  @override
  void initState() {
    super.initState();
    if (!_ownsController) {
      controller = widget.controller;
      visible = widget.visible;
    } else if (widget.visible && widget.adConfig!.isEnable) {
      controller = createNativeController(
        factory: widget.factory,
        adConfig: widget.adConfig!,
        adExpandConfig: widget.expandedAdConfig,
        adKey: widget.adKey,
        enableAutoReload: widget.enableAutoReload,
        customOptions: widget.customOptions,
      );
      controller?.load();
      visible = true;
    } else {
      visible = false;
    }
    if (widget.enableAutoReload) {
      autoReload();
    }
  }

  @override
  void didUpdateWidget(covariant AutoReloadNativeAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ownsController &&
        (oldWidget.controller != widget.controller ||
            oldWidget.visible != widget.visible)) {
      controller = widget.controller;
      visible = widget.visible;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.ignoreRouteObserver || _observer != null) {
      return;
    }
    _observer = RouterScope.of(
      context,
    ).firstObserverOfType<AutoRouteObserver>();
    _observer?.subscribe(this, context.routeData);
  }

  @override
  void didPushNext() {
    if (widget.enableAutoReload) {
      isCurrentScreen = false;
      // controller?.disposeAd();
      reloadTimerService?.pause();
    }
    super.didPushNext();
  }

  @override
  void didPopNext() {
    if (widget.enableAutoReload) {
      isCurrentScreen = true;
      // controller?.load();
      reloadTimerService?.resume();
    }
    super.didPopNext();
  }

  void autoReload() {
    reloadTimerService = ReloadTimerService();
    reloadTimerService?.start(
      interval: RemoteConfigManager.instance.adsRemoteConfig.cbFetchInterval,
      onReset: () {
        controller?.reload();
      },
    );
    _statusSubscription = controller?.stream.listen((event) {
      if (event.isLoading) {
        reloadTimerService?.pause();
      } else if ((event.isImpression || event.isLoadFailed) && !isPaused) {
        reloadTimerService?.reset();
        if (isCurrentScreen) {
          reloadTimerService?.resume();
        }
      }
    });
    appLifecycleListener = AppLifecycleListener(
      onStateChange: (value) {
        if (!isCurrentScreen) {
          return;
        }
        if (value == AppLifecycleState.resumed) {
          isPaused = false;
          reloadTimerService?.resume();
        } else if (value == AppLifecycleState.paused) {
          isPaused = true;
          reloadTimerService?.pause();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!visible || controller == null) {
      return SizedBox(
        height: widget.offAdMaintainSize
            ? _type?.calculateAdHeight(widget.placeholderHeight ?? 0)
            : widget.placeholderHeight,
      );
    }
    if (controller is NativeCollapsibleBannerController) {
      return CustomNativeBannerAd.control(
        controller: controller! as NativeCollapsibleBannerController,
        offAdMaintainSize: widget.offAdMaintainSize,
        ignoreCubit: widget.ignoreCubit,
        hideMaintainSize: widget.hideMaintainSize,
        placeholderHeight: widget.placeholderHeight,
        customLoading: widget.customLoading,
      );
    } else {
      return Padding(
        padding: widget.padding ?? EdgeInsets.zero,
        child: CommonNativeAd.control(
          controller: controller! as NativeAdController,
          type: _type,
          offAdMaintainSize: widget.offAdMaintainSize,
          ignoreCubit: widget.ignoreCubit,
          hideMaintainSize: widget.hideMaintainSize,
          placeholderHeight: widget.placeholderHeight,
          customLoading: widget.customLoading,
        ),
      );
    }
  }

  @override
  void dispose() {
    reloadTimerService?.dispose();
    _statusSubscription?.cancel();
    appLifecycleListener?.dispose();
    if (_ownsController) {
      controller?.dispose();
    }
    _observer?.unsubscribe(this);
    super.dispose();
  }
}
