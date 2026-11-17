import 'package:material_ui/material_ui.dart';

import '../../../config/di/di.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/date/dates.dart';
import '../../../core/date_parser/quick_add_parser.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../shared/extension/context_extension.dart';
import '../../../shared/helpers/day_clock.dart';
import '../../../shared/helpers/task_format.dart';

/// Always-visible "add a task" field with natural-language dates.
///
/// Recognised words are highlighted in the field and summarised as chips
/// below; the ✕ chip keeps the text literal.
class QuickAddField extends StatefulWidget {
  const QuickAddField({
    super.key,
    this.defaultDate,
    this.listId,
    this.autofocus = false,
    this.onSubmitted,
  });

  /// Used when the text has no date (e.g. Today → today)
  final DateTime? defaultDate;
  final String? listId;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  State<QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends State<QuickAddField> {
  late final _controller = _HighlightController();
  final _focus = FocusNode();
  QuickAddResult? _result;
  bool _ignoreParsing = false;
  bool _saving = false;

  QuickAddParser _parser(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final monthFirst =
        locale.languageCode == 'en' &&
        (locale.countryCode == null || locale.countryCode == 'US');
    return QuickAddParser(dayFirst: !monthFirst);
  }

  void _onChanged(String text) {
    if (text.trim().isEmpty) {
      _ignoreParsing = false;
    }
    final result = text.trim().isEmpty
        ? null
        : _parser(context).parse(text, DateTime.now());
    setState(() {
      _result = result;
      _controller.spans = _ignoreParsing || result == null
          ? const []
          : result.spans;
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) {
      _focus.unfocus();
      return;
    }
    _saving = true;
    final parsed = _ignoreParsing
        ? null
        : _parser(context).parse(text, DateTime.now());
    final date = parsed?.date ?? widget.defaultDate;
    final time = parsed?.date == null ? null : parsed?.time;
    try {
      await getIt<TaskRepository>().create(
        TaskDraft(
          title: parsed?.title ?? text,
          listId: widget.listId,
          dueDate: date,
          dueTime: time,
          rrule: parsed?.recurrence?.toRule(),
          priority: parsed?.priority ?? 0,
          // A time typed in = "remind me then"
          remindOffset: time == null ? null : 0,
        ),
      );
    } finally {
      _saving = false;
    }
    if (!mounted) {
      return;
    }
    _controller.clear();
    _onChanged('');
    widget.onSubmitted?.call();
    if (time != null) {
      await getIt<ReminderService>().ensurePermission(context);
    }
    if (!mounted) {
      return;
    }
    final defaultDate = widget.defaultDate;
    if (date != null &&
        (defaultDate == null || !Dates.isSameDay(date, defaultDate))) {
      final label = TaskFormat.day(context, date, getIt<DayClock>().value);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.addedTo(label))));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.highlight = context.colorScheme.primary;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final result = _result;
    final showChips = !_ignoreParsing && result != null && !result.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _onChanged,
          onSubmitted: (_) async {
            await _submit();
            if (mounted) {
              _focus.requestFocus();
            }
          },
          decoration: InputDecoration(
            labelText: context.l10n.addTask,
            hintText: context.l10n.quickAddHint,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            prefixIcon: Icon(Icons.add_rounded, color: scheme.primary),
            suffixIcon: _controller.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: context.l10n.addTask,
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      color: scheme.primary,
                    ),
                    onPressed: _submit,
                  ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.topCenter,
          child: showChips
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ParsedChips(
                    result: result,
                    onIgnore: () => setState(() {
                      _ignoreParsing = true;
                      _controller.spans = const [];
                    }),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _ParsedChips extends StatelessWidget {
  const _ParsedChips({required this.result, required this.onIgnore});

  final QuickAddResult result;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final today = getIt<DayClock>().value;
    final date = result.date;
    final time = result.time;
    final rec = result.recurrence;
    final labels = <(IconData, String, Color?)>[
      if (date != null)
        (Icons.event_rounded, TaskFormat.day(context, date, today), null),
      if (time != null)
        (Icons.schedule_rounded, TaskFormat.time(context, time), null),
      if (rec != null)
        (Icons.repeat_rounded, TaskFormat.recurrence(context, rec), null),
      if (result.priority > 0)
        (
          Icons.flag_rounded,
          TaskFormat.priority(context.l10n, result.priority),
          context.taskColors.priority(result.priority),
        ),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (icon, label, color) in labels)
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(icon, size: 16, color: color ?? scheme.primary),
            label: Text(label),
          ),
        ActionChip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.close_rounded, size: 16),
          label: Text(context.l10n.keepAsText),
          onPressed: onIgnore,
        ),
      ],
    );
  }
}

/// Paints recognised date/time words in the primary colour
class _HighlightController extends TextEditingController {
  List<(int, int)> spans = const [];
  Color highlight = Colors.teal;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Don't fight the IME while a Vietnamese word is being composed
    if (spans.isEmpty || value.composing.isValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final children = <TextSpan>[];
    var cursor = 0;
    for (final (start, end) in spans) {
      if (start < cursor || end > text.length) {
        continue;
      }
      if (start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, start)));
      }
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            color: highlight,
            fontWeight: FontWeight.w600,
            backgroundColor: highlight.withValues(alpha: .12),
          ),
        ),
      );
      cursor = end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }
}
