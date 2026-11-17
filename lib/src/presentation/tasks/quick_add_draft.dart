import 'package:material_ui/material_ui.dart';

import '../../core/date_parser/quick_add_parser.dart';
import '../../data/repositories/task_repository.dart';

/// Parser that reads dates the way the user's locale writes them
/// (20/11 = 20 Nov, except US English)
QuickAddParser quickAddParserFor(BuildContext context) {
  final locale = Localizations.localeOf(context);
  final monthFirst =
      locale.languageCode == 'en' &&
      (locale.countryCode == null || locale.countryCode == 'US');
  return QuickAddParser(dayFirst: !monthFirst);
}

/// Turns one line of typed text into a task, the same way everywhere:
/// recognised words become the schedule, [defaultDate] fills in a missing
/// date, a typed time means "remind me then".
///
/// The optional [list], [priority] and [time] are accepted suggestions;
/// anything typed explicitly wins over them.
TaskDraft draftFromText(
  String text,
  QuickAddResult? parsed, {
  DateTime? defaultDate,
  String? listId,
  String? list,
  int? priority,
  int? time,
}) {
  final date = parsed?.date ?? defaultDate;
  final typedTime = parsed?.date == null ? null : parsed?.time;
  // A time needs a day to land on
  final dueTime = date == null ? null : typedTime ?? time;
  final typedPriority = parsed?.priority ?? 0;
  return TaskDraft(
    title: parsed?.title ?? text.trim(),
    listId: listId ?? list,
    dueDate: date,
    dueTime: dueTime,
    rrule: parsed?.recurrence?.toRule(),
    priority: typedPriority > 0 ? typedPriority : priority ?? 0,
    remindOffset: dueTime == null ? null : 0,
  );
}
