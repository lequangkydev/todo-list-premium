import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:injectable/injectable.dart';
import 'package:material_ui/material_ui.dart';

import '../../presentation/completed/completed_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/language/language_screen.dart';
import '../../presentation/lists/list_detail_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/permission/permission_screen.dart';
import '../../presentation/search/search_screen.dart';
import '../../presentation/setting/setting_screen.dart';
import '../../presentation/splash/splash_screen.dart';
import '../../presentation/uninstall/uninstall_screen.dart';
import '../theme/app_theme.dart';

part 'app_router.gr.dart';

@singleton
@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  AppRouter();

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(page: SplashRoute.page, initial: true),
    AutoRoute(page: LanguageRoute.page),
    AutoRoute(page: OnBoardingRoute.page),
    AutoRoute(page: PermissionRoute.page),
    AutoRoute(page: HomeRoute.page),
    AutoRoute(page: SettingRoute.page),
    AutoRoute(page: UninstallRoute.page),
    AutoRoute(page: ListDetailRoute.page),
    AutoRoute(page: CompletedRoute.page),
    // Search replaces the current view rather than going deeper
    CustomRoute<void>(
      page: SearchRoute.page,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      transitionsBuilder: _fadeThrough,
    ),
  ];
}

Widget _fadeThrough(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (!AppMotion.enabled(context)) {
    return child;
  }
  return FadeThroughTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    fillColor: Theme.of(context).scaffoldBackgroundColor,
    child: child,
  );
}
