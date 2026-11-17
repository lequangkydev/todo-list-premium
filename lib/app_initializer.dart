import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_iap/flutter_iap.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'flavors.dart';
import 'module/adjust/adjust.dart';
import 'module/admob/utils/utils.dart';
import 'module/remote_config/remote_config.dart';
import 'src/config/di/di.dart';
import 'src/core/backup/backup_service.dart';
import 'src/core/focus/focus_service.dart';
import 'src/core/notifications/reminder_service.dart';
import 'src/core/widgets/launch_links.dart';
import 'src/core/widgets/widget_sync.dart';
import 'src/data/local/shared_preferences_manager.dart';
import 'src/shared/constants/app_constants.dart';
import 'src/shared/global.dart';
import 'src/shared/helpers/method_channel/notification_channel.dart';
import 'src/shared/helpers/utils.dart';

class AppInitializer {
  AppInitializer._();

  static final AppInitializer instance = AppInitializer._();

  Future<void> init() async {
    configureDependencies();
    await Future.wait([
      Firebase.initializeApp(),
      _initHydrateBlocStorage(),
      SharedPreferencesManager.instance.initialize(),
      initGlobalData(),
      // Month/day names for every locale, offline
      initializeDateFormatting(),
    ]);
    await RemoteConfigManager.instance.initConfig();
    _initAdjust();
    _initIAP();
    // Keeps pending notifications in sync with tasks — runs in background
    unawaited(getIt<ReminderService>().start());
    // Home-screen widgets mirror today's tasks; links from them open Home
    unawaited(getIt<WidgetSync>().start());
    unawaited(LaunchLinks.instance.start());
    // Today's backup, if it hasn't been made yet (also on every resume)
    unawaited(getIt<BackupService>().start());
    // A focus block may be running, or have finished while the app was closed
    unawaited(getIt<FocusService>().start());

    _settingSystemUI();
  }

  Future<void> initGlobalData() async {
    final result = await Future.wait([
      getApplicationDocumentsDirectory(),
      getTemporaryDirectory(),
    ]);
    Global.instance.documentPath = result[0].path;
    Global.instance.temporaryPath = result[1].path;
    if (Platform.isAndroid) {
      Global.instance.androidSdkVersion =
          (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    }
  }

  Future<void> _initAdjust() {
    final adjustEnvironment = F.appFlavor == Flavor.dev || kDebugMode
        ? AdjustEnvironment.sandbox
        : AdjustEnvironment.production;
    if (const bool.hasEnvironment('FULL_ADS') && F.appFlavor == Flavor.dev) {
      MyAds.instance.isFullAds = const bool.fromEnvironment('FULL_ADS');
      NotificationChannel.enableNotification(MyAds.instance.isFullAds);
    }
    final adjustConfig = RemoteConfigManager.instance.adjustConfig;
    return AdjustUtil.instance.initialize(
      // Kiểm tra môi trường Adjust
      environment: adjustEnvironment,
      // Token app của Adjust
      appToken: AdjustToken(
        androidToken: adjustConfig.appToken,
        iosToken: adjustConfig.appToken,
      ),
      // Cấu hình cho ad
      adOptions: AdOptions(
        androidAdOptions: AndroidAdOptions(
          // Token event để log các sự kiện impression của ad lên Adjust
          impressionToken: adjustConfig.eventToken,
          event80Token: adjustConfig.event80Token,
          // Callback khi ad kiểm tra xem có phải là full ad không
          fullAdCallback: (isSuper, network, fromCache, fromLib, fromApi) {
            if (const bool.hasEnvironment('FULL_ADS')) {
              isSuper = const bool.fromEnvironment('FULL_ADS');
            }
            MyAds.instance.isFullAds = isSuper;
            NotificationChannel.enableNotification(isSuper);
          },
        ),
      ),
      fullAdsOption: adjustConfig.fullAdsOption,
      apiToken: adjustConfig.apiToken,
    );
  }

  Future<HydratedStorage> _initHydrateBlocStorage() async {
    final Directory documentDir = await getApplicationDocumentsDirectory();
    return HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(documentDir.path),
    );
  }

  //show hide bottom navigation bar of device
  void _settingSystemUI() {
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (Platform.isAndroid) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      );

      hideNavigationBar();
      SystemChrome.setSystemUIChangeCallback((
        bool systemOverlaysAreVisible,
      ) async {
        if (systemOverlaysAreVisible) {
          Future<void>.delayed(const Duration(seconds: 3), hideNavigationBar);
        }
      });
    }
  }

  Future<void> _initIAP() async {
    if (!RemoteConfigManager.instance.iapConfig.enable) {
      return;
    }
    await PurchasesManager.instance.init(
      productId: AppConstants.premiumWeeklyProductId,

      /// đăt enableDebugMode = false nếu muốn load sản phẩm thật ở chế độ prod debug
      /// ở chế độ release thì tự động load sản phẩm thật
      // enableDebugMode: false,
    );
    PurchasesManager.instance.onPurchaseSuccess = (_) {
      setEnableAppOpenAd(false);
    };
  }
}
