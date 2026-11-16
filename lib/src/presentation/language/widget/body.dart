part of '../language_screen.dart';

class _BodyWidget extends StatefulWidget {
  const _BodyWidget({required this.isFirst});

  final bool isFirst;

  @override
  State<_BodyWidget> createState() => _BodyWidgetState();
}

class _BodyWidgetState extends State<_BodyWidget> {
  final languageList = [...Language.values];

  Language get suggestLanguage {
    final systemLanguageCode = Platform.localeName.split('_').first;
    final suggestLanguage = Language.values.firstWhere(
      (element) => element.languageCode == systemLanguageCode,
      orElse: () => Language.english,
    );
    return suggestLanguage;
  }

  @override
  void initState() {
    languageList.remove(suggestLanguage);
    // Phone's language first; clamp so a short list doesn't throw
    languageList.insert(
      languageList.length.clamp(0, 3) == 3 ? 3 : 0,
      suggestLanguage,
    );
    super.initState();
  }

  /// Chừa chỗ cuối list cho ad neo đáy (ad đè lên list)
  double get _adPadding {
    final bool hasAd;
    final double adHeight;
    if (widget.isFirst) {
      hasAd =
          adUnitsConfig.nativeLanguage.isEnable ||
          adUnitsConfig.nativeLanguageSelect.isEnable;
      adHeight = adUnitsConfig.nativeLanguage.type.calculateAdHeight(70);
    } else {
      final slot = NativeAllUtil.instance.config.nativeLanguageSetting;
      hasAd = adUnitsConfig.nativeBanner.isEnable && slot.isEnable;
      adHeight = slot.type.calculateAdHeight(70);
    }
    return hasAd ? adHeight : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: BlocBuilder<ValueCubit<Language?>, Language?>(
            builder: (context, state) {
              return ListView.separated(
                separatorBuilder: (context, index) => 8.vSpace,
                padding: EdgeInsets.fromLTRB(16, 24, 16, 22.h + _adPadding),
                itemCount: languageList.length,
                itemBuilder: (BuildContext context1, int index) {
                  final Language item = languageList[index];
                  return Stack(
                    children: [
                      _LanguageItem(
                        key: ValueKey(item),
                        context: context,
                        language: item,
                        selectedValue: state,
                      ),
                      if (item == suggestLanguage && state == null)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Padding(
                              padding: EdgeInsets.only(right: 30.w),
                              child: Assets.lottie.tap.lottie(),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
