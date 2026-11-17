import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/date/dates.dart';
import '../../core/lunar/festivals.dart';
import '../../core/lunar/lunar_calendar.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/cubit/language_cubit.dart';
import '../../shared/cubit/lunar_cubit.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/task_format.dart';
import '../tasks/widgets/quick_add_field.dart';
import '../tasks/widgets/task_sources.dart';
import '../tasks/widgets/task_tile.dart';

/// A month grid with a dot per task (and lunar dates when on). Tap a day to
/// see its tasks below; long-press a task and drop it on another day to
/// move it.
class MonthView extends StatefulWidget {
  const MonthView({super.key, required this.today});

  final DateTime today;

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  late DateTime _focused = widget.today;
  late DateTime _selected = widget.today;

  /// +1 when the newly selected day is later, so its list slides in from
  /// the end; -1 from the start
  int _direction = 1;

  final _repo = getIt<TaskRepository>();

  /// The calendar's own page controller, for the header's arrows
  PageController? _pages;

  /// One stream per visible month, including the days shown from the
  /// neighbouring months
  late final _tasks = KeyedStream<DateTime, List<Task>>(
    (month) => _repo.watchRange(
      Dates.addDays(month, -7),
      Dates.addDays(DateTime(month.year, month.month + 1), 6),
    ),
  );

  void _page(int delta) {
    AppHaptics.selection();
    final pages = _pages;
    if (pages == null) {
      return;
    }
    final duration = AppMotion.of(context, AppMotion.slow);
    if (delta < 0) {
      pages.previousPage(duration: duration, curve: AppMotion.curve);
    } else {
      pages.nextPage(duration: duration, curve: AppMotion.curve);
    }
  }

  void _select(DateTime day) {
    final d = Dates.dateOnly(day);
    if (Dates.isSameDay(d, _selected)) {
      return;
    }
    AppHaptics.selection();
    setState(() {
      _direction = d.isAfter(_selected) ? 1 : -1;
      _selected = d;
      _focused = d;
    });
  }

  Future<void> _move(Task task, DateTime day) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final label = TaskFormat.day(context, day, widget.today);
    AppHaptics.light();
    await _repo.setDue(task.id, day, task.dueTime);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.movedTo(label)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => _repo.updateTask(task),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>().state;
    final lunar = context.watch<LunarCubit>().showFor(language);
    final month = DateTime(_focused.year, _focused.month);
    return StreamBuilder<List<Task>>(
      stream: _tasks.of(month),
      builder: (context, snapshot) {
        final byDay = <DateTime, List<Task>>{};
        for (final task in snapshot.data ?? const <Task>[]) {
          byDay.putIfAbsent(task.dueDate!, () => []).add(task);
        }
        final dayTasks = byDay[_selected] ?? const <Task>[];
        return TaskLookupsBuilder(
          builder: (context, lookups) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _MonthHeader(
                      month: month,
                      showToday:
                          month.year != widget.today.year ||
                          month.month != widget.today.month,
                      onPrevious: () => _page(-1),
                      onNext: () => _page(1),
                      onToday: () => setState(() {
                        _direction = widget.today.isAfter(_selected) ? 1 : -1;
                        _focused = widget.today;
                        _selected = widget.today;
                      }),
                    ),
                    _Calendar(
                      today: widget.today,
                      focused: _focused,
                      selected: _selected,
                      lunar: lunar,
                      tasksOn: (day) => byDay[Dates.dateOnly(day)] ?? const [],
                      onSelect: _select,
                      onPage: (focused) => setState(() => _focused = focused),
                      onDrop: _move,
                      onCreated: (pages) => _pages = pages,
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _DayHeader(
                  day: _selected,
                  today: widget.today,
                  lunar: lunar,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  0,
                  AppSpace.gutter,
                  AppSpace.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: QuickAddField(
                    key: ValueKey(_selected),
                    defaultDate: _selected,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.medium),
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(_selected);
                    final dir = Directionality.of(context) == TextDirection.rtl
                        ? -_direction
                        : _direction;
                    final from = (incoming ? .25 : -.25) * dir;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: Offset(from, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_selected),
                    child: dayTasks.isEmpty
                        ? _EmptyDay(hasTasks: byDay.isNotEmpty)
                        : TaskGroup(
                            children: [
                              for (final task in dayTasks)
                                _DraggableTask(
                                  key: ValueKey(task.id),
                                  task: task,
                                  child: TaskTile(
                                    task: task,
                                    today: widget.today,
                                    showDate: false,
                                    subtasks: lookups.subtasks[task.id],
                                    list: lookups.listOf(task),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        );
      },
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.today,
    required this.focused,
    required this.selected,
    required this.lunar,
    required this.tasksOn,
    required this.onSelect,
    required this.onPage,
    required this.onDrop,
    required this.onCreated,
  });

  final void Function(PageController pages) onCreated;
  final DateTime today;
  final DateTime focused;
  final DateTime selected;
  final bool lunar;
  final List<Task> Function(DateTime day) tasksOn;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onPage;
  final Future<void> Function(Task task, DateTime day) onDrop;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = context.colorScheme;
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    Widget cell(DateTime day, {bool outside = false}) => _DayCell(
      day: Dates.dateOnly(day),
      today: today,
      selected: Dates.isSameDay(day, selected),
      outside: outside,
      lunar: lunar,
      count: tasksOn(day).length,
      onDrop: onDrop,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      child: TableCalendar<Task>(
        locale: Localizations.localeOf(context).toLanguageTag(),
        firstDay: DateTime(today.year - 1),
        lastDay: DateTime(today.year + 5, 12, 31),
        focusedDay: focused,
        currentDay: today,
        selectedDayPredicate: (day) => Dates.isSameDay(day, selected),
        startingDayOfWeek: firstDay == 0
            ? StartingDayOfWeek.sunday
            : firstDay == 6
            ? StartingDayOfWeek.saturday
            : StartingDayOfWeek.monday,
        availableCalendarFormats: const {CalendarFormat.month: ''},
        rowHeight: lunar ? 60 : 50,
        pageAnimationDuration: AppMotion.of(context, AppMotion.slow),
        pageAnimationCurve: AppMotion.curve,
        eventLoader: tasksOn,
        onDaySelected: (day, _) => onSelect(day),
        onPageChanged: onPage,
        onCalendarCreated: onCreated,
        // Its header buttons are legacy-Material InkWells, which find no
        // Material ancestor under material_ui; _MonthHeader replaces it
        headerVisible: false,
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: text.labelSmall!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          weekendStyle: text.labelSmall!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        calendarBuilders: CalendarBuilders<Task>(
          defaultBuilder: (context, day, _) => cell(day),
          todayBuilder: (context, day, _) => cell(day),
          selectedBuilder: (context, day, _) => cell(day),
          outsideBuilder: (context, day, _) => cell(day, outside: true),
          markerBuilder: (context, day, tasks) => tasks.isEmpty
              ? null
              : Positioned(bottom: 5, child: _Dots(tasks: tasks)),
        ),
      ),
    );
  }
}

/// "November 2026" with arrows, and "Today" when another month is shown
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.showToday,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final bool showToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final material = MaterialLocalizations.of(context);
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.sm,
        AppSpace.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                DateFormat.yMMMM(locale).format(month),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.fast),
            child: showToday
                ? TextButton(
                    key: const ValueKey('today'),
                    onPressed: onToday,
                    child: Text(context.l10n.today),
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: material.previousMonthTooltip,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: scheme.onSurfaceVariant,
            ),
            onPressed: onPrevious,
          ),
          IconButton(
            tooltip: material.nextMonthTooltip,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
            ),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// A day of the grid: solar day, lunar day under it, and a drop target
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.selected,
    required this.outside,
    required this.lunar,
    required this.count,
    required this.onDrop,
  });

  final DateTime day;
  final DateTime today;
  final bool selected;
  final bool outside;
  final bool lunar;
  final int count;
  final Future<void> Function(Task task, DateTime day) onDrop;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final isToday = Dates.isSameDay(day, today);
    final lunarDate = lunar ? LunarDate.fromSolar(day) : null;
    final festival = lunarDate == null ? null : LunarFestival.of(lunarDate);
    final festivalColor = context.taskColors.priorityHigh;
    final dayColor = selected
        ? scheme.onPrimary
        : outside
        ? scheme.onSurfaceVariant.withValues(alpha: .6)
        : scheme.onSurface;
    final label = [
      TaskFormat.longDay(context, day),
      if (lunarDate != null) TaskFormat.lunar(l10n, day),
      if (festival != null) TaskFormat.festival(l10n, festival),
    ].join(', ');
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) =>
          !Dates.isSameDay(details.data.dueDate ?? day, day),
      onAcceptWithDetails: (details) => onDrop(details.data, day),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Semantics(
          label: label,
          selected: selected,
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.fast),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary
                  : hovering
                  ? scheme.primaryContainer
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: isToday && !selected
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: text.bodyMedium?.copyWith(
                    color: dayColor,
                    fontWeight: isToday || selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (lunarDate != null)
                  Text(
                    // The month shows on its first day
                    lunarDate.day == 1
                        ? '${lunarDate.day}/${lunarDate.month}'
                        : '${lunarDate.day}',
                    style: text.labelSmall?.copyWith(
                      fontSize: 9,
                      height: 1.1,
                      color: selected
                          ? scheme.onPrimary.withValues(alpha: .85)
                          : festival != null
                          ? festivalColor
                          : scheme.onSurfaceVariant,
                      fontWeight: festival != null || lunarDate.day == 1
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                // Room for the task dots
                if (count > 0) const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Up to three dots in the colours of the day's priorities
class _Dots extends StatelessWidget {
  const _Dots({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final sorted = [...tasks]..sort((a, b) => b.priority.compareTo(a.priority));
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in sorted.take(3))
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.priority > 0
                    ? context.taskColors.priority(t.priority)
                    : context.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// "Fri, 20 Nov · 24/9 âm lịch · Tết Trung Thu"
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.today,
    required this.lunar,
  });

  final DateTime day;
  final DateTime today;
  final bool lunar;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = context.colorScheme;
    final lunarDate = LunarDate.fromSolar(day);
    final festival = lunar ? LunarFestival.of(lunarDate) : null;
    final relative = TaskFormat.day(context, day, today);
    final long = TaskFormat.longDay(context, day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter + 4,
        AppSpace.md,
        AppSpace.gutter,
        AppSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              relative == long ? long : '$relative · $long',
              style: text.titleSmall,
            ),
          ),
          if (lunar)
            Text(
              [
                TaskFormat.lunar(l10n, day),
                if (festival != null) TaskFormat.festival(l10n, festival),
              ].join(' · '),
              style: text.bodySmall?.copyWith(
                color: festival != null
                    ? context.taskColors.priorityHigh
                    : scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.hasTasks});

  /// Other days this month have tasks: say how to move one here
  final bool hasTasks;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.lg,
      ),
      child: Column(
        children: [
          Text(
            context.l10n.nothingOnDay,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (hasTasks) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              context.l10n.dragHint,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Long-press to pick a task up and drop it on a day of the grid
class _DraggableTask extends StatelessWidget {
  const _DraggableTask({super.key, required this.task, required this.child});

  final Task task;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return LongPressDraggable<Task>(
      data: task,
      onDragStarted: AppHaptics.selection,
      feedback: Material(
        elevation: 8,
        shadowColor: scheme.primary.withValues(alpha: .35),
        color: context.taskColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: .4, child: child),
      child: child,
    );
  }
}
