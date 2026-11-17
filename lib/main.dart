import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_ads/ads_flutter.dart';
import 'package:material_ui/material_ui.dart';

import 'app_initializer.dart';
import 'flavors.dart';
import 'src/presentation/app.dart';
import 'src/shared/helpers/logger_utils.dart';

Future<void> main() async {
  F.appFlavor = Flavor.values.firstWhere(
    (element) => element.name == appFlavor,
    orElse: () => Flavor.prod,
  );
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    RegularNativeHeightBus.ensureInitialized();
    await AppInitializer.instance.init();
    runApp(
      const MyApp(),
    );
  }, (error, stack) {
    logger.e('ERROR', error: error, stackTrace: stack);
  });
}
