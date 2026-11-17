import 'package:flutter_base/src/gen/l18n/app_localizations.dart';
import 'package:flutter_base/src/shared/l10n/app_delegates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Material moved to its own package in Flutter 3.47, with its own
  // localisations. The generated delegate list still points at the
  // framework's, and with it every non-English language broke the first
  // AppBar: this keeps all 16 working.
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('Material widgets build in ${locale.languageCode}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(title: const Text('x'), leading: const BackButton()),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 9, minute: 0),
                ),
                child: Text(AppLocalizations.of(context).today),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        MaterialLocalizations.of(tester.element(find.byType(AppBar))),
        isNotNull,
      );
      // A dialog that leans on MaterialLocalizations
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
