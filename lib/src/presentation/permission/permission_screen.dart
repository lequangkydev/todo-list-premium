import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../module/admob/model/ad_config/ad_config.dart';
import '../../../module/admob/utils/utils.dart';
import '../../../module/admob/widget/ads/auto_reload_native_ad.dart';
import '../../../module/tracking_screen/loggable_widget.dart';
import '../../config/di/di.dart';
import '../../config/navigation/app_router.dart';
import '../../config/theme/app_theme.dart';
import '../../core/notifications/reminder_service.dart';
import '../../data/local/shared_preferences_manager.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/permission_util.dart';
import '../../shared/widgets/custom_appbar.dart';
import 'cubit/cubit.dart';

part 'widget/permission_body.dart';

@RoutePage()
class PermissionScreen extends StatefulLoggableWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  AdController? controller;
  AdController? storageController;

  @override
  void initState() {
    if (adUnitsConfig.nativePermission.isEnable) {
      controller = createNativeController(
        factory: AdFactory.bottomNativeAd,
        adConfig: adUnitsConfig.nativePermission,
        adKey: 'native_permission',
      );
      controller!.load();
    }

    if (adUnitsConfig.nativePermissionStorage.isEnable) {
      storageController = createNativeController(
        factory: AdFactory.bottomNativeAd,
        adConfig: adUnitsConfig.nativePermissionStorage,
        adKey: 'native_permission_storage',
      );
    }
    super.initState();
  }

  void switchAdController(AdController? value) {
    if (value == null) {
      return;
    }
    if (!value.status.isLoading) {
      value.reload();
    }
    setState(() {
      controller = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<StoragePermissionCubit, bool>(
          listenWhen: (previous, current) => current,
          listener: (context, state) {
            switchAdController(storageController);
          },
        ),
      ],
      child: Scaffold(
        appBar: CustomAppbar(titleText: context.l10n.permission),
        body: SafeArea(child: PermissionBody(adController: controller)),
      ),
    );
  }
}
