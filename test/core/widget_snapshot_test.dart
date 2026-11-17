import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/core/notifications/reminder_planner.dart';
import 'package:flutter_base/src/core/widgets/launch_links.dart';
import 'package:flutter_base/src/core/widgets/widget_sync.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/gen/l18n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final today = DateTime(2026, 11, 13);
var _id = 0;

Task t(String title, {DateTime? due, int? time, int priority = 0}) => Task(
  id: 'id${_id++}',
  title: title,
  dueDate: due ?? today,
  dueTime: time,
  priority: priority,
  isDone: false,
  reminders: const [],
  alarm: false,
  sortOrder: 1,
  createdAt: today,
  updatedAt: today,
);

void main() {
  setUpAll(() => initializeDateFormatting());

  group('WidgetSnapshot', () {
    test("today's tasks first, then overdue; labels for every count", () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final overdue = t('Old', due: DateTime(2026, 11, 10), time: 600);
      final call = t('Call', time: 9 * 60, priority: 3);
      final walk = t('Walk');
      final s = WidgetSnapshot.build(
        due: [overdue, call, walk],
        done: 2,
        today: today,
        l10n: l10n,
        locale: 'en',
      );
      final items = (s['items']! as List).cast<Map<String, Object?>>();
      expect(items.map((i) => i['title']), ['Call', 'Walk', 'Old']);
      // CLDR puts a narrow no-break space before AM/PM
      expect(items[0]['time'], '9:00\u202fAM');
      expect(items[0]['p'], 3);
      // Every id its notifications may have, for the iOS widget to cancel
      expect(items[0]['nids'], [
        ReminderPlanner.notificationIdOf('${call.id}:snooze'),
      ]);
      // An overdue task's time belongs to another day
      expect(items[2]['time'], isNull);
      expect(items[2]['late'], isTrue);
      expect(s['open'], 3);
      expect(s['done'], 2);
      expect(s['date'], '2026-11-13');
      final labels = s['l']! as Map<String, Object?>;
      expect(labels['title'], l10n.today);
      expect((labels['left']! as Map).keys, ['0', '1', '2', '3']);
      expect((labels['left']! as Map)['3'], l10n.summaryRemaining(3));
      expect((labels['done']! as Map).keys, ['2', '3', '4', '5']);
    });

    test('caps the list, 24-hour times and RTL by language', () {
      final ar = WidgetSnapshot.build(
        due: [for (var i = 0; i < 20; i++) t('T$i', time: 21 * 60)],
        done: 0,
        today: today,
        l10n: lookupAppLocalizations(const Locale('ar')),
        locale: 'ar',
      );
      expect(ar['items'], hasLength(WidgetSnapshot.maxItems));
      expect(ar['open'], 20);
      expect(ar['rtl'], isTrue);

      final vi = WidgetSnapshot.build(
        due: [t('Họp', time: 21 * 60)],
        done: 0,
        today: today,
        l10n: lookupAppLocalizations(const Locale('vi')),
        locale: 'vi',
      );
      expect(((vi['items']! as List).first as Map)['time'], '21:00');
      expect(vi['rtl'], isFalse);
    });
  });

  group('LaunchLinks', () {
    test('keeps only app links, and hands each out once', () {
      final links = LaunchLinks.instance;
      links.open(Uri.parse('https://example.com'));
      expect(links.pending.value, isNull);
      links.open(Uri.parse('todolist://task?id=abc&homeWidget'));
      expect(links.take()?.queryParameters['id'], 'abc');
      expect(links.take(), isNull);
    });
  });
}
