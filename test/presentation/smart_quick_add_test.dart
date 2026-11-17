import 'package:drift/native.dart';
import 'package:flutter_base/src/config/di/di.dart';
import 'package:flutter_base/src/config/theme/app_theme.dart';
import 'package:flutter_base/src/core/ai/smart_suggestions.dart';
import 'package:flutter_base/src/core/date_parser/quick_add_parser.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/data/repositories/list_repository.dart';
import 'package:flutter_base/src/data/repositories/task_repository.dart';
import 'package:flutter_base/src/gen/l18n/app_localizations.dart';
import 'package:flutter_base/src/presentation/tasks/quick_add_draft.dart';
import 'package:flutter_base/src/presentation/tasks/widgets/quick_add_field.dart';
import 'package:flutter_base/src/shared/cubit/haptics_cubit.dart';
import 'package:flutter_base/src/shared/cubit/smart_suggestions_cubit.dart';
import 'package:flutter_base/src/shared/helpers/day_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:material_ui/material_ui.dart';

class _MemoryStorage implements Storage {
  final _data = <String, dynamic>{};

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> close() async {}
}

void main() {
  group('draftFromText', () {
    final now = DateTime(2026, 11, 13, 10);
    final today = DateTime(2026, 11, 13);
    QuickAddResult p(String s) => QuickAddParser().parse(s, now);

    test('typed values win over accepted suggestions', () {
      final d = draftFromText(
        'Họp 9h !!',
        p('Họp 9h !!'),
        defaultDate: today,
        list: 'work',
        priority: 3,
        time: 600,
      );
      expect(d.title, 'Họp');
      expect(d.dueTime, 540);
      expect(d.priority, 2);
      expect(d.listId, 'work');
      expect(d.remindOffset, 0);
    });

    test('accepted time needs a day', () {
      expect(draftFromText('Chạy bộ', null, time: 360).dueTime, isNull);
      final d = draftFromText(
        'Chạy bộ',
        p('Chạy bộ'),
        defaultDate: today,
        time: 360,
      );
      expect(d.dueDate, today);
      expect(d.dueTime, 360);
      expect(d.remindOffset, 0);
    });

    test('the field list beats a suggested list', () {
      final d = draftFromText('x', null, listId: 'home', list: 'work');
      expect(d.listId, 'home');
    });
  });

  group('QuickAddField suggestions', () {
    late AppDatabase db;
    late TaskRepository tasks;
    late ListRepository lists;

    setUp(() {
      HydratedBloc.storage = _MemoryStorage();
      db = AppDatabase(NativeDatabase.memory());
      tasks = TaskRepository(db);
      lists = ListRepository(db);
      final smartCubit = SmartSuggestionsCubit();
      getIt
        ..registerSingleton<TaskRepository>(tasks)
        ..registerSingleton<ListRepository>(lists)
        ..registerSingleton<HapticsCubit>(HapticsCubit())
        ..registerSingleton<SmartSuggestionsCubit>(smartCubit)
        ..registerSingleton<DayClock>(DayClock())
        ..registerLazySingleton<SmartSuggestions>(
          () => SmartSuggestions(tasks, smartCubit),
        );
    });

    tearDown(() async {
      getIt<DayClock>().dispose();
      await getIt.reset(dispose: false);
      await db.close();
    });

    /// Streams opened in the real zone must be closed there too
    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      // Drift closes a cancelled stream on a zero-length timer
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(() => getIt<SmartSuggestions>().dispose());
    }

    Future<String> seed(WidgetTester tester) async {
      return (await tester.runAsync(() async {
        final shop = await lists.create('Groceries', 0xFF4F7A6B);
        for (final t in ['Mua sữa', 'Mua trứng', 'Mua rau', 'Mua gạo']) {
          await tasks.create(TaskDraft(title: t, listId: shop));
        }
        await tasks.create(const TaskDraft(title: 'Gọi điện cho ngân hàng'));
        return shop;
      }))!;
    }

    Future<void> pumpField(WidgetTester tester) async {
      // The engine learns from the database stream (real async), then
      // debounces
      await tester.runAsync(() async {
        getIt<SmartSuggestions>();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: QuickAddField()),
        ),
      );
    }

    Future<List<Task>> saved(WidgetTester tester, String title) async {
      return (await tester.runAsync(
        () => (db.select(db.tasks)..where((t) => t.title.equals(title))).get(),
      ))!;
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a list suggestion is used only when tapped', (tester) async {
      final shop = await seed(tester);
      await pumpField(tester);

      await tester.enterText(find.byType(TextField), 'Mua sữa tươi');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Groceries'), findsOneWidget);

      // Not tapped → not applied
      await submit(tester);
      expect((await saved(tester, 'Mua sữa tươi')).single.listId, isNull);

      await tester.enterText(find.byType(TextField), 'Mua trứng gà');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Groceries'));
      await tester.pumpAndSettle();
      await submit(tester);
      expect((await saved(tester, 'Mua trứng gà')).single.listId, shop);
      await finish(tester);
    });

    testWidgets('warns about an open task with the same text', (tester) async {
      await seed(tester);
      await pumpField(tester);
      await tester.enterText(find.byType(TextField), 'goi dien cho ngan hang');
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(QuickAddField)),
      );
      expect(
        find.text(l10n.duplicateHint('Gọi điện cho ngân hàng')),
        findsOneWidget,
      );
      await finish(tester);
    });

    testWidgets('offers to split several scheduled tasks', (tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(TextField), 'Họp 9h, gọi khách 14h');
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(QuickAddField)),
      );
      expect(find.text(l10n.splitIntoTasks(2)), findsOneWidget);
      await finish(tester);
    });

    testWidgets('switched off: no suggestions', (tester) async {
      await seed(tester);
      getIt<SmartSuggestionsCubit>().update(false);
      await pumpField(tester);
      await tester.enterText(find.byType(TextField), 'Mua sữa tươi');
      await tester.pumpAndSettle();
      expect(find.byType(FilterChip), findsNothing);
      await finish(tester);
    });
  });
}
