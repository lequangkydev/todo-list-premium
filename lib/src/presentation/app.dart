import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_iap/flutter_iap.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:material_ui/material_ui.dart';

import '../../module/remote_config/remote_config.dart';
import '../config/di/di.dart';
import '../config/navigation/app_router.dart';
import '../config/observer/route_observer.dart';
import '../config/theme/app_theme.dart';
import '../gen/l18n/app_localizations.dart';
import '../shared/cubit/ad_visibility_cubit.dart';
import '../shared/cubit/haptics_cubit.dart';
import '../shared/cubit/language_cubit.dart';
import '../shared/cubit/lunar_cubit.dart';
import '../shared/cubit/rate_status_cubit.dart';
import '../shared/cubit/smart_suggestions_cubit.dart';
import '../shared/cubit/theme_mode_cubit.dart';
import '../shared/enum/language.dart';
import '../shared/helpers/permission_util.dart';
import '../shared/helpers/shortcut_utils.dart';

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Same instance as getIt so services (reminders) see language changes
        BlocProvider.value(value: getIt<LanguageCubit>()),
        BlocProvider.value(value: getIt<ThemeModeCubit>()),
        BlocProvider.value(value: getIt<HapticsCubit>()),
        BlocProvider.value(value: getIt<SmartSuggestionsCubit>()),
        BlocProvider.value(value: getIt<LunarCubit>()),
        BlocProvider(create: (context) => AdVisibilityCubit()),
        BlocProvider(create: (context) => RateStatusCubit()),
        BlocProvider(
          create: (context) => PermissionUtil.instance.photoPermissionCubit,
        ),
        BlocProvider(
          create: (context) => PermissionUtil.instance.cameraPermissionCubit,
        ),
        BlocProvider(
          create: (context) =>
              PermissionUtil.instance.notificationPermissionCubit,
        ),
      ],
      child: ScreenUtilInit(
        // TODO(all): Change designSize to your design size
        designSize: const Size(360, 800),
        minTextAdapt: true,
        useInheritedMediaQuery: true,
        splitScreenMode: true,
        builder: (context, child) => GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: const BodyApp(),
        ),
      ),
    );
  }
}

class BodyApp extends StatelessWidget {
  const BodyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LanguageCubit, Language?>(
      listener: (context, state) {
        if (state != null) {
          Future.delayed(
            const Duration(milliseconds: 500),
            ShortcutUtils.instance.setShortcutItems,
          );
        }
      },
      builder: (context, state) {
        final themeMode = context.watch<ThemeModeCubit>().state;
        return MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: state?.locale,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: themeMode,
          routerConfig: getIt<AppRouter>().config(
            navigatorObservers: () => [MainRouteObserver()],
          ),
          builder: MyAds.instance.overlayBuilder((context, child) {
            configIapScreen(context);
            // Opening one row's swipe actions closes the others
            return SlidableAutoCloseBehavior(
              child: EasyLoading.init()(context, child),
            );
          }),
        );
      },
    );
  }

  void configIapScreen(BuildContext context) {
    if (!RemoteConfigManager.instance.iapConfig.enable) {
      return;
    }
    final isFreeTrial = PurchasesManager.instance.state.products.length > 1;
    PurchasesManager.instance.config(
      templateData: TemplateDataModel(
        // logo cho template 1
        //   iconPath: Assets.images.logo.logo.path,
        //   // các feature
        features: [
          // FeatureDataModel(
          //   icon: Assets.icons.unlock.svg(),
          //   text: context.l10n.supportUnlimitedDevices,
          // ),
          // FeatureDataModel(
          //   icon: Assets.icons.flash.svg(),
          //   text: context.l10n.ultraFastConnection,
          // ),
          // FeatureDataModel(
          //   icon: Assets.icons.noAds.svg(),
          //   text: context.l10n.enjoyAnAdFreeExperience,
          // ),
        ],
        //   background: Assets.images.bgIap.image(fit: BoxFit.cover),
        termsOfUseUrl: RemoteConfigManager.instance.appConfig.urlTerms,
        privacyPolicyUrl: RemoteConfigManager.instance.appConfig.urlPolicy,
        //   title: context.l10n.getPremium,
        //   subtitle: context.l10n.upgradeToPremium,
        //   editorChoiceText: context.l10n.editorsChoice,
        //   buttonWidget: GradientButton(
        //     onPressed: PurchasesManager.instance.buy,
        //     child: Text(
        //       isFreeTrial
        //           ? context.l10n.start3DayFreeTrial
        //           : context.l10n.continueText,
        //       style: TextStyle(
        //         fontSize: 20.sp,
        //         fontWeight: .w700,
        //         color: Colors.black,
        //       ),
        //     ),
        //   ),
        //   priceTextBuilder: (priceText, rawPrice, currencyCode) {
        //     return context.l10n.thenForPriceWeekly(priceText);
        //   },
        //
        //   termOfUseText: context.l10n.termOfUse,
        //   restorePurchaseText: context.l10n.restorePurchase,
        //   privacyPolicyText: context.l10n.policy,
      ),
    );
  }
}
