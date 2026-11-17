import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import '../../gen/l18n/app_localizations.dart';

/// Localisation delegates for the app.
///
/// Not `AppLocalizations.localizationsDelegates`: that generated list uses
/// the framework's own `GlobalMaterialLocalizations`, which `material_ui`
/// widgets don't look up (since Flutter 3.47 Material lives in its own
/// package, with its own localisations). With it, every language except
/// English fails with "No MaterialLocalizations found" as soon as an
/// AppBar, date picker or dialog builds.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];
