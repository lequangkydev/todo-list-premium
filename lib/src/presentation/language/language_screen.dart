import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../module/admob/model/ad_config/ad_config.dart';
import '../../../module/admob/utils/native_all_util.dart';
import '../../../module/admob/utils/utils.dart';
import '../../../module/admob/widget/ads/auto_reload_native_ad.dart';
import '../../../module/admob/widget/ads/native_all_ad.dart';
import '../../../module/tracking_screen/loggable_widget.dart';
import '../../config/navigation/app_router.dart';
import '../../config/theme/app_theme.dart';
import '../../gen/assets.gen.dart';
import '../../shared/cubit/language_cubit.dart';
import '../../shared/cubit/value_cubit.dart';
import '../../shared/enum/language.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/extension/number_extension.dart';
import '../../shared/widgets/button/custom_button.dart';
import '../../shared/widgets/custom_appbar.dart';
import '../../shared/widgets/custom_radio.dart';
import '../onboarding/utils/intro_ad_util.dart';

part 'widget/body.dart';
part 'widget/item.dart';

@RoutePage()
class LanguageScreen extends StatefulLoggableWidget
    implements AutoRouteWrapper {
  const LanguageScreen({super.key, this.isFirst = false});

  final bool isFirst;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    final Language currentLanguage = context.read<LanguageCubit>().state;
    return BlocProvider(
      create: (context) =>
          ValueCubit<Language?>(isFirst ? null : currentLanguage),
      child: this,
    );
  }
}

class _LanguageScreenState extends State<LanguageScreen>
    with SingleTickerProviderStateMixin {
  /// Điều phối 2 native ad (nativeLanguage ↔ nativeLanguageSelect) theo ưu tiên Meta.
  late final DualNativeAdSwitcher _adSwitcher;

  /// Gate nút Accept: 0 = cho bấm; > 0 = số giây đếm ngược đang khóa.
  final ValueNotifier<int> _saveGate = ValueNotifier<int>(0);
  Timer? _selectCountdownTimer;
  bool _selectionHandled = false;

  /// True trong 2s "đang dịch" ngay sau khi chọn ngôn ngữ.
  final ValueNotifier<bool> _isTranslating = ValueNotifier<bool>(false);
  Timer? _translatingTimer;

  static const int _kSelectShowSeconds = 2;
  static const Duration _kTranslatingDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    if (widget.isFirst) {
      _adSwitcher = _createAdSwitcher();
      _adSwitcher.start();
      streamLanguageSelectCtrl();
      if (MyAds.instance.isFullAds) {
        showNativeFull();
      }
    }
  }

  DualNativeAdSwitcher _createAdSwitcher() {
    return DualNativeAdSwitcher(
      primary: NativeAdSlot(
        build: () => adUnitsConfig.nativeLanguage.isEnable
            ? createNativeController(
                factory: AdFactory.bottomNativeAd,
                adConfig: adUnitsConfig.nativeLanguage,
                adKey: 'native_language',
              )
            : null,
        type: adUnitsConfig.nativeLanguage.type,
      ),
      select: NativeAdSlot(
        build: () => adUnitsConfig.nativeLanguageSelect.isEnable
            ? createNativeController(
                factory: AdFactory.bottomNativeAd,
                adConfig: adUnitsConfig.nativeLanguageSelect,
                adKey: 'native_language_select',
              )
            : null,
        type: adUnitsConfig.nativeLanguageSelect.type,
      ),
    );
  }

  void _goToNextScreen() {
    final Language? selectedLanguage = context
        .read<ValueCubit<Language?>>()
        .state;
    if (selectedLanguage == null) {
      Fluttertoast.showToast(
        msg: context.l10n.selectLanguageGuide,
        gravity: ToastGravity.CENTER,
      );
      return;
    }
    context.read<LanguageCubit>().update(selectedLanguage);
    if (widget.isFirst) {
      context.replaceRoute(const OnBoardingRoute());
      return;
    }

    // trường hợp ở màn language setting
    if (MyAds.instance.isFullAds) {
      IntroAdUtil.instance.preloadAd1();
      context.router.replaceAll([const OnBoardingRoute()]);
    } else {
      context.router.popUntilRouteWithName(HomeRoute.name);
    }
  }

  void streamLanguageSelectCtrl() {
    final selectController = _adSwitcher.selectController;
    if (selectController != null && MyAds.instance.isFullAds) {
      selectController.onAdClicked = (ad) {
        _goToNextScreen();
      };
    }
  }

  void _handleLanguageSelected() {
    if (_selectionHandled) {
      return;
    }
    _selectionHandled = true;
    IntroAdUtil.instance.preloadAd1();
    _startTranslatingFlow();
  }

  /// Hiện "đang dịch" 2s (text + loading); hết 2s → hiện nativeLanguageSelect
  /// rồi mở đếm ngược 2s ở nút Accept.
  void _startTranslatingFlow() {
    _translatingTimer?.cancel();
    _selectCountdownTimer?.cancel();
    _saveGate.value = 0;
    _isTranslating.value = true;
    _translatingTimer = Timer(_kTranslatingDuration, () {
      if (!mounted) {
        return;
      }
      _isTranslating.value = false;
      _adSwitcher.showSelect(lock: true);
      _startSelectCountdown();
    });
  }

  void _startSelectCountdown() {
    _selectCountdownTimer?.cancel();
    _saveGate.value = _kSelectShowSeconds;
    _selectCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final int next = _saveGate.value - 1;
      _saveGate.value = next <= 0 ? 0 : next;
      if (next <= 0) {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ValueCubit<Language?>, Language?>(
      listenWhen: (previous, current) {
        return previous == null;
      },
      listener: (context, state) {
        if (state != null && widget.isFirst) {
          _handleLanguageSelected();
        }
      },
      child: Scaffold(
        appBar: CustomAppbar(
          showBackButton: !widget.isFirst,
          titleText: context.l10n.language,
          actions: [_buildAcceptButton()],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  if (widget.isFirst) _buildGuide(),
                  Expanded(child: _BodyWidget(isFirst: widget.isFirst)),
                ],
              ),
            ),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildAd()),
          ],
        ),
      ),
    );
  }

  /// Text guide đổi theo pha "đang dịch"
  Widget _buildGuide() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 0),
      child: ValueListenableBuilder<bool>(
        valueListenable: _isTranslating,
        builder: (context, translating, _) {
          if (!translating) {
            return Text(
              context.l10n.selectLanguageGuide,
              textAlign: TextAlign.center,
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(context.l10n.translatingLanguage)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAd() {
    return widget.isFirst
        ? ValueListenableBuilder<AdController?>(
            valueListenable: _adSwitcher.adController,
            builder: (context, controller, _) {
              return AutoReloadNativeAd.control(
                key: ValueKey(controller?.adKey),
                controller: controller,
                type: _adSwitcher.currentType,
              );
            },
          )
        : NativeAllAd(
            slot: NativeAllUtil.instance.config.nativeLanguageSetting,
          );
  }

  Builder _buildAcceptButton() {
    return Builder(
      builder: (context) {
        final Language? selectedLanguage = context
            .watch<ValueCubit<Language?>>()
            .state;
        if (selectedLanguage == null && widget.isFirst) {
          return const SizedBox();
        }
        return AnimatedBuilder(
          animation: Listenable.merge([_isTranslating, _saveGate]),
          builder: (context, _) {
            final int gate = _saveGate.value;
            // khoá trong pha "đang dịch" và lúc đếm ngược
            final bool locked = _isTranslating.value || gate != 0;
            return Opacity(
              opacity: locked ? .5 : 1,
              child: CustomButton(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                onTap: locked ? null : _goToNextScreen,
                child: gate > 0
                    ? Text(
                        '${gate}s',
                        style: TextStyle(color: context.colorScheme.onSurface),
                      )
                    : Icon(Icons.check, color: context.colorScheme.onSurface),
              ),
            );
          },
        );
      },
    );
  }

  void showNativeFull() {
    Future.delayed(Duration.zero, () {
      nativeFullSplashUtil.show(onClose: () => _adSwitcher.showPrimary());
    });
  }

  @override
  void dispose() {
    _translatingTimer?.cancel();
    _selectCountdownTimer?.cancel();
    _isTranslating.dispose();
    _saveGate.dispose();
    if (widget.isFirst) {
      _adSwitcher.dispose();
    }
    super.dispose();
  }
}
