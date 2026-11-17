import 'package:drift/native.dart';
import 'package:flutter_base/src/config/di/di.dart';
import 'package:flutter_base/src/config/theme/app_theme.dart';
import 'package:flutter_base/src/core/lunar/lunar_calendar.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/data/repositories/list_repository.dart';
import 'package:flutter_base/src/data/repositories/task_repository.dart';
import 'package:flutter_base/src/gen/l18n/app_localizations.dart';
import 'package:flutter_base/src/presentation/upcoming/month_view.dart';
import 'package:flutter_base/src/shared/cubit/haptics_cubit.dart';
import 'package:flutter_base/src/shared/cubit/language_cubit.dart';
import 'package:flutter_base/src/shared/cubit/lunar_cubit.dart';
import 'package:flutter_base/src/shared/helpers/day_clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
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
  final today = DateTime(2026, 11, 13);
  late AppDatabase db;
  late TaskRepository tasks;

  setUpAll(() => initializeDateFormatting());

  setUp(() {
    HydratedBloc.storage = _MemoryStorage();
    db = AppDatabase(NativeDatabase.memory());
    tasks = TaskRepository(db);
    getIt
      ..registerSingleton<TaskRepository>(tasks)
      ..registerSingleton<ListRepository>(ListRepository(db))
      ..registerSingleton<HapticsCubit>(HapticsCubit())
      ..registerSingleton<LanguageCubit>(LanguageCubit())
      ..registerSingleton<LunarCubit>(LunarCubit())
      ..registerSingleton<DayClock>(DayClock());
  });

  tearDown(() async {
    getIt<DayClock>().dispose();
    await getIt.reset(dispose: false);
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tasks.create(TaskDraft(title: 'Pay rent', dueDate: today));
      await tasks.create(
        TaskDraft(
          title: 'Dentist',
          dueDate: DateTime(2026, 11, 20),
          priority: 3,
        ),
      );
    });
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: getIt<LanguageCubit>()),
          BlocProvider.value(value: getIt<LunarCubit>()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MonthView(today: today)),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Drift closes cancelled streams on a zero-length timer
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets("shows the selected day's tasks; tapping a day shows its own", (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Pay rent'), findsOneWidget);
    expect(find.text('Dentist'), findsNothing);

    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    expect(find.text('Dentist'), findsOneWidget);
    expect(find.text('Pay rent'), findsNothing);
    await finish(tester);
  });

  testWidgets('lunar dates and festivals when the lunar calendar is on', (
    tester,
  ) async {
    getIt<LunarCubit>().update(true);
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(MonthView)));
    final lunarToday = LunarDate.fromSolar(today);
    expect(
      find.textContaining(
        l10n.lunarDate('${lunarToday.day}/${lunarToday.month}'),
      ),
      findsOneWidget,
    );
    await finish(tester);
  });
}
