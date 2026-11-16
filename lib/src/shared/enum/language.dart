import 'dart:ui';

/// UI languages. The quick-add date parser understands Vietnamese and
/// English whichever language is selected.
enum Language {
  english(languageName: 'English', languageCode: 'en', flag: 'gb'),
  vietnamese(languageName: 'Tiếng Việt', languageCode: 'vi', flag: 'vn'),
  spanish(languageName: 'Español', languageCode: 'es', flag: 'es'),
  french(languageName: 'Français', languageCode: 'fr', flag: 'fr'),
  german(languageName: 'Deutsch', languageCode: 'de', flag: 'de'),
  italian(languageName: 'Italiano', languageCode: 'it', flag: 'it'),
  portuguese(languageName: 'Português', languageCode: 'pt', flag: 'br'),
  russian(languageName: 'Русский', languageCode: 'ru', flag: 'ru'),
  turkish(languageName: 'Türkçe', languageCode: 'tr', flag: 'tr'),
  arabic(languageName: 'العربية', languageCode: 'ar', flag: 'sa'),
  hindi(languageName: 'हिन्दी', languageCode: 'hi', flag: 'in'),
  indonesian(languageName: 'Bahasa Indonesia', languageCode: 'id', flag: 'id'),
  thai(languageName: 'ไทย', languageCode: 'th', flag: 'th'),
  japanese(languageName: '日本語', languageCode: 'ja', flag: 'jp'),
  korean(languageName: '한국어', languageCode: 'ko', flag: 'kr'),
  chinese(languageName: '简体中文', languageCode: 'zh', flag: 'cn');

  const Language({
    required this.languageCode,
    required this.languageName,
    required this.flag,
  });

  final String languageCode;
  final String languageName;

  /// circle-flags (MIT) — `assets/images/languages/flag_<flag>.svg`
  final String flag;

  /// Right-to-left script
  bool get isRtl => this == Language.arabic;

  @override
  String toString() => languageName;
}

extension LanguageExtension on Language {
  String get flagPath => 'assets/images/languages/flag_$flag.svg';

  Locale get locale => switch (this) {
    Language.portuguese => const Locale('pt', 'BR'),
    _ => Locale(languageCode),
  };
}
