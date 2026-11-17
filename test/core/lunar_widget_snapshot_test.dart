import 'package:flutter_base/src/core/lunar/lunar_calendar.dart';
import 'package:flutter_base/src/core/widgets/lunar_widget_snapshot.dart';
import 'package:flutter_base/src/gen/l18n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  Map<String, Map<String, Object?>> days(String locale, DateTime today) {
    final snapshot = LunarWidgetSnapshot.build(
      today: today,
      l10n: lookupAppLocalizations(Locale(locale)),
      locale: locale,
    );
    return (snapshot['days']! as Map).cast<String, Map<String, Object?>>();
  }

  test('a row for each of the coming days, keyed by date', () {
    final table = days('vi', DateTime(2026, 2, 10));
    expect(table, hasLength(LunarWidgetSnapshot.days));
    expect(table.keys.first, '2026-02-10');
    expect(table.keys.last, '2026-06-09');
  });

  test('Tết 2026 in Vietnamese: lunar date, festival, year name', () {
    final l10n = lookupAppLocalizations(const Locale('vi'));
    final tet = days('vi', DateTime(2026, 2, 10))['2026-02-17']!;
    expect(tet['d'], 17);
    expect(tet['w'], 'Thứ Ba');
    expect(tet['l'], l10n.lunarDate('1/1'));
    expect(tet['f'], l10n.festTet);
    expect(tet['y'], 'Năm Bính Ngọ');
    // The day before still belongs to the old year
    final eve = days('vi', DateTime(2026, 2, 10))['2026-02-16']!;
    expect(eve['y'], 'Năm Ất Tỵ');
    expect(eve.containsKey('f'), isFalse);
  });

  test('other languages get translated labels and no year name', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final tet = days('en', DateTime(2026, 2, 10))['2026-02-17']!;
    expect(tet['w'], 'Tuesday');
    expect(tet['m'], 'February 2026');
    expect(tet['l'], l10n.lunarDate('1/1'));
    expect(tet.containsKey('y'), isFalse);
  });

  test('year names follow the sixty-year cycle', () {
    expect(LunarCalendar.canChiYear(2024), 'Giáp Thìn');
    expect(LunarCalendar.canChiYear(2025), 'Ất Tỵ');
    expect(LunarCalendar.canChiYear(2026), 'Bính Ngọ');
    expect(LunarCalendar.canChiYear(1984), 'Giáp Tý');
    expect(LunarCalendar.canChiYear(2044), 'Giáp Tý');
  });
}
