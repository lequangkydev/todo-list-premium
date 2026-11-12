import 'dart:async';

import 'package:flutter_ads/ads_flutter.dart';

import '../model/ad_config/ad_config.dart';
import '../model/native_all_config/native_all_config.dart';
import 'utils.dart';

/// Native "all": buffer AD ở core + tạo controller MỚI mỗi lần hiển thị.
/// KHÔNG pool controller (tránh impression-oan cùng adUnitId + leak).
class NativeAllUtil {
  NativeAllUtil._();

  static final instance = NativeAllUtil._();

  final List<AdController> _used = [];

  NativeAllConfig config = const NativeAllConfig();

  /// Số ad giữ sẵn trong buffer core (autoRefill tự nạp lại sau mỗi acquire).
  static const int bufferSize = 1;

  /// NativeAll chủ động warm để hiện tức thì → bật refill (giữ buffer đầy).
  static const bool autoRefill = true;

  bool get _enabled => adUnitsConfig.nativeBanner.isEnable;

  /// Ad unit id hợp lệ của 1 config (id-based).
  List<String> _adUnitIds(AdUnitConfig adConfig) =>
      [adConfig.id].where((id) => id.isNotEmpty).toList();

  /// Có vị trí (đang bật) nào dùng collapsibleBanner → cần warm cả ad expand.
  bool _needExpand() {
    if (adUnitsConfig.nativeBanner.type == NativeAdType.collapsibleBanner) {
      return true;
    }
    return config.allSlots.any(
      (slot) => slot.isEnable && slot.type == NativeAdType.collapsibleBanner,
    );
  }

  /// Warm buffer core → acquire luôn có ad sẵn, kể cả vào lại màn nhiều lần.
  void warm() {
    if (!_enabled) {
      return;
    }
    for (final id in _adUnitIds(adUnitsConfig.nativeBanner)) {
      unawaited(
        NativeAdPoolUtil.preload(
          adUnitId: id,
          bufferSize: bufferSize,
          autoRefill: autoRefill,
        ),
      );
    }
    if (_needExpand()) {
      for (final id in _adUnitIds(adUnitsConfig.nativeBannerExpand)) {
        unawaited(
          NativeAdPoolUtil.preload(
            adUnitId: id,
            bufferSize: bufferSize,
            autoRefill: autoRefill,
          ),
        );
      }
    }
  }

  void preloadAd() => warm();

  void preloadSlots() => warm();

  /// Tạo controller MỚI cho vị trí (type của slot). Ad lấy từ buffer core.
  AdController? getController({NativeAdType? type}) {
    if (!_enabled) {
      return null;
    }
    final controller = createNativeController(
      factory: AdFactory.mediumNativeAd,
      adConfig: adUnitsConfig.nativeBanner,
      adExpandConfig: adUnitsConfig.nativeBannerExpand,
      type: type ?? adUnitsConfig.nativeBanner.type,
      adKey: 'native_all',
      enableAutoReload: true,
      autoRefill: autoRefill,
    );
    _used.add(controller);
    controller.load();
    return controller;
  }

  void disposeController(AdController controller) {
    controller.dispose();
    _used.remove(controller);
  }
}
