import 'package:flutter_ads/ads_flutter.dart';

import '../model/ad_config/ad_config.dart';
import 'utils.dart';

class CachedNativeAdUtil {
  CachedNativeAdUtil({
    required this.adConfig,
    this.adExpandConfig,
    this.factory = AdFactory.mediumNativeAd,
    this.reloadOnImpression = false,
    this.visible = true,
    this.enableAutoReload = false,
    this.adKey,
  });

  final AdUnitConfig adConfig;
  final AdUnitConfig? adExpandConfig;

  final AdFactory factory;
  final bool reloadOnImpression;
  final bool visible;
  final bool enableAutoReload;
  final String? adKey;

  // Các controller đã được load và đang đợi sử dụng
  final List<AdController> _controllers = [];

  // Các controller đang được sử dụng
  final List<AdController> _usedControllers = [];

  bool get isEnableAd {
    return adConfig.isEnable && visible;
  }

  /// Load trước ad
  void preloadAd() {
    if (!isEnableAd) {
      return;
    }
    // Kiểm tra xem trong danh sách controller có controller nào chưa impression
    // và không bị lỗi
    final index = _controllers.indexWhere(
      (element) => !element.isImpression && !element.status.isLoadFailed,
    );
    // Nếu đã có controller chưa impression thì không load nữa
    if (index != -1) {
      return;
    }
    // Khi khong có controller nào chưa impression sẽ tạo 1 controller mới
    final AdController controller = createNewController();
    _controllers.add(controller);
  }

  AdController createNewController() {
    final AdController controller = createNativeController(
      factory: factory,
      adConfig: adConfig,
      adExpandConfig: adExpandConfig,
      adKey: adKey,
      enableAutoReload: enableAutoReload,
    );

    if (reloadOnImpression) {
      controller.onAdImpression = (ad) {
        preloadAd();
      };
    }
    controller.load();
    return controller;
  }

  /// Lấy ra 1 controller trong danh sách [_controller] chưa impression
  AdController? getController() {
    if (!isEnableAd) {
      return null;
    }
    // Kiểm tra xem trong danh sách controller có controller nào chưa impression
    // và không bị lỗi
    final index = _controllers.indexWhere(
      (element) => !element.isImpression && !element.status.isLoadFailed,
    );
    AdController controller;
    if (index == -1) {
      // Tạo 1 controller mới nếu chưa có controller nào không impression
      controller = createNewController();
      _usedControllers.add(controller);
    } else {
      // chuyển controller chưa impression vào _usedControllers
      controller = _controllers[index];
      _usedControllers.add(controller);
      _controllers.removeAt(index);
    }
    return controller;
  }

  void disposeController(AdController controller) {
    if (controller.isImpression) {
      // dispose controller và xoá khỏi danh sách nếu như controller đó đã impression
      controller.dispose();
      _usedControllers.remove(controller);
      return;
    }

    // chuyển lại controller về danh sách _controller nếu nó chưa impresssion
    // và không load lỗi
    if (controller.status.isLoadFailed) {
      controller.dispose();
    } else {
      _controllers.add(controller);
    }
    _usedControllers.remove(controller);
  }

  void reloadUsedAd() {
    if (!isEnableAd) {
      return;
    }
    for (var element in _usedControllers) {
      if (element.isImpression) {
        element.reload();
      }
    }
  }
}
