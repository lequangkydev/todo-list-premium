import 'dart:ui';

import '../../gen/assets.gen.dart';

/// UI languages. The quick-add parser understands Vietnamese and English
/// whichever is selected.
enum Language {
  english(languageName: 'English', languageCode: 'en'),
  vietnamese(languageName: 'Tiếng Việt', languageCode: 'vi');

  const Language({required this.languageCode, required this.languageName});

  final String languageCode;
  final String languageName;

  @override
  String toString() => languageName;
}

extension LanguageExtension on Language {
  String get flagPath => switch (this) {
    Language.english => Assets.images.languages.en.path,
    Language.vietnamese => Assets.images.languages.vi.path,
  };

  Locale get locale => switch (this) {
    Language.english => const Locale('en'),
    Language.vietnamese => const Locale('vi'),
  };
}
