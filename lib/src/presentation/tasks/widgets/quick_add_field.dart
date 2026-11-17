import 'package:material_ui/material_ui.dart';

import '../../../config/di/di.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/ai/smart_suggestions.dart';
import '../../../core/ai/suggestion_engine.dart';
import '../../../core/date/dates.dart';
import '../../../core/date_parser/quick_add_parser.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/list_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../shared/extension/context_extension.dart';
import '../../../shared/helpers/app_haptics.dart';
import '../../../shared/helpers/day_clock.dart';
import '../../../shared/helpers/task_format.dart';
import '../../../shared/widgets/motion.dart';
import '../../reminders/reminder_nudge.dart';
import '../brain_dump_sheet.dart';
import '../quick_add_draft.dart';
import '../task_editor_sheet.dart';

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
  late final _lists = getIt<ListRepository>().watchLists();
  QuickAddResult? _result;
  bool _ignoreParsing = false;
  bool _saving = false;
  String _last = '';

  /// Suggestions for what's typed, and which ones the user tapped to use
  TaskHints _hints = TaskHints.none;
  bool _useList = false;
  bool _usePriority = false;
  bool _useTime = false;

  /// The text read as several tasks (empty unless there are 2+)
  List<String> _pieces = const [];

  SmartSuggestions get _smart => getIt<SmartSuggestions>();

  void _onChanged(String text) {
    // A hardware Enter at the end submits, like the keyboard's Done
    if (text.length == _last.length + 1 &&
        text.endsWith('\n') &&
        text.startsWith(_last) &&
        !_last.contains('\n')) {
      _controller.value = TextEditingValue(
        text: _last,
        selection: TextSelection.collapsed(offset: _last.length),
      );
      _submit();
      return;
    }
    _last = text;
    if (text.trim().isEmpty) {
      _ignoreParsing = false;
    }
    final result = text.trim().isEmpty
        ? null
        : quickAddParserFor(context).parse(text, DateTime.now());
    final parsed = _ignoreParsing ? null : result;
    final date = parsed?.date ?? widget.defaultDate;
    final hints = text.trim().length < 3 || text.contains('\n')
        ? TaskHints.none
        : _smart.hints(
            parsed?.title ?? text,
            listId: widget.listId,
            // Typed time wins; with no day there's nothing to time
            hasTime: parsed?.time != null || date == null,
          );
    setState(() {
      _result = result;
      _controller.spans = parsed?.spans ?? const [];
      // A changed suggestion has to be accepted again
      if (hints.listId != _hints.listId) {
        _useList = false;
      }
      if (hints.priority != _hints.priority) {
        _usePriority = false;
      }
      if (hints.time != _hints.time) {
        _useTime = false;
      }
      _hints = hints;
      if (text.trim().isEmpty) {
        _pieces = const [];
      }
    });
    if (text.trim().isNotEmpty) {
      _smart.provider.splitTasks(text).then((pieces) {
        if (mounted && _controller.text == text) {
          setState(() => _pieces = pieces.length > 1 ? pieces : const []);
        }
      });
    }
  }

  Future<void> _openBrainDump(String initial) async {
    final added = await BrainDumpSheet.show(
      context,
      initialText: initial,
      defaultDate: widget.defaultDate,
      listId: widget.listId,
    );
    if ((added ?? false) && mounted) {
      _controller.clear();
      _onChanged('');
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) {
      _focus.unfocus();
      return;
    }
    if (text.contains('\n')) {
      // Pasted lines: review them as separate tasks
      return _openBrainDump(text);
    }
    _saving = true;
    final parsed = _ignoreParsing
        ? null
        : quickAddParserFor(context).parse(text, DateTime.now());
    final hints = _hints;
    final draft = draftFromText(
      text,
      parsed,
      defaultDate: widget.defaultDate,
      listId: widget.listId,
      list: _useList ? hints.listId : null,
      priority: _usePriority ? hints.priority : null,
      time: _useTime ? hints.time : null,
    );
    try {
      await getIt<TaskRepository>().create(draft);
    } finally {
      _saving = false;
    }
    if (!mounted) {
      return;
    }
    _controller.clear();
    _onChanged('');
    widget.onSubmitted?.call();
    final date = draft.dueDate;
    if (draft.dueTime != null) {
      await afterReminderSet(context);
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
    final l10n = context.l10n;
    final result = _ignoreParsing ? null : _result;
    final hasText = _controller.text.trim().isNotEmpty;
    final showParsed = result != null && !result.isEmpty;
    final duplicate = _hints.duplicate;
    final showChips =
        hasText &&
        (showParsed ||
            _hints.listId != null ||
            _hints.priority != null ||
            _hints.time != null ||
            _pieces.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          // Multi-line so pasted lines survive (a single-line field drops
          // the breaks); the keyboard still shows Done
          maxLines: null,
          keyboardType: TextInputType.text,
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
            labelText: l10n.addTask,
            hintText: l10n.quickAddHint,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            prefixIcon: Icon(Icons.add_rounded, color: scheme.primary),
            suffixIcon: hasText
                ? IconButton(
                    tooltip: l10n.addTask,
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      color: scheme.primary,
                    ),
                    onPressed: _submit,
                  )
                : IconButton(
                    tooltip: l10n.addMany,
                    icon: Icon(
                      Icons.playlist_add_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    onPressed: () => _openBrainDump(''),
                  ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.medium),
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showChips)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: StreamBuilder<List<ListWithCount>>(
                    stream: _lists,
                    builder: (context, lists) => _Chips(
                      result: showParsed ? result : null,
                      hints: _hints,
                      lists: {
                        for (final l in lists.data ?? const <ListWithCount>[])
                          l.list.id: l.list,
                      },
                      useList: _useList,
                      usePriority: _usePriority,
                      useTime: _useTime,
                      onToggleList: () => setState(() => _useList = !_useList),
                      onTogglePriority: () =>
                          setState(() => _usePriority = !_usePriority),
                      onToggleTime: () => setState(() => _useTime = !_useTime),
                      pieces: _pieces.length,
                      onSplit: () => _openBrainDump(_pieces.join('\n')),
                      onIgnore: () => setState(() {
                        _ignoreParsing = true;
                        _controller.spans = const [];
                      }),
                    ),
                  ),
                ),
              if (hasText && duplicate != null)
                Entrance(
                  key: ValueKey(duplicate.id),
                  child: _DuplicateNote(task: duplicate),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Recognised schedule (filled chips), suggestions (tap to use), and a
/// shortcut to split the text into several tasks
class _Chips extends StatelessWidget {
  const _Chips({
    required this.result,
    required this.hints,
    required this.lists,
    required this.useList,
    required this.usePriority,
    required this.useTime,
    required this.onToggleList,
    required this.onTogglePriority,
    required this.onToggleTime,
    required this.pieces,
    required this.onSplit,
    required this.onIgnore,
  });

  final QuickAddResult? result;
  final TaskHints hints;
  final Map<String, TaskList> lists;
  final bool useList;
  final bool usePriority;
  final bool useTime;
  final VoidCallback onToggleList;
  final VoidCallback onTogglePriority;
  final VoidCallback onToggleTime;
  final int pieces;
  final VoidCallback onSplit;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final today = getIt<DayClock>().value;
    final parsed = result;
    final date = parsed?.date;
    final time = parsed?.time;
    final rec = parsed?.recurrence;
    // Keyed by kind so a chip animates in once, not on every keystroke
    final labels = <(String, IconData, String, Color?)>[
      if (date != null)
        (
          'date',
          Icons.event_rounded,
          TaskFormat.day(context, date, today),
          null,
        ),
      if (time != null)
        ('time', Icons.schedule_rounded, TaskFormat.time(context, time), null),
      if (rec != null)
        (
          'repeat',
          Icons.repeat_rounded,
          TaskFormat.recurrence(context, rec),
          null,
        ),
      if (parsed != null && parsed.priority > 0)
        (
          'priority',
          Icons.flag_rounded,
          TaskFormat.priority(l10n, parsed.priority),
          context.taskColors.priority(parsed.priority),
        ),
    ];
    final suggestedList = lists[hints.listId];
    final suggestedPriority = hints.priority;
    final suggestedTime = hints.time;
    final suggestions = <(String, String, Color, bool, VoidCallback)>[
      if (suggestedList != null)
        (
          's-list',
          suggestedList.name,
          Color(suggestedList.colorValue),
          useList,
          onToggleList,
        ),
      if (suggestedPriority != null && (parsed?.priority ?? 0) == 0)
        (
          's-priority',
          TaskFormat.priority(l10n, suggestedPriority),
          context.taskColors.priority(suggestedPriority),
          usePriority,
          onTogglePriority,
        ),
      if (suggestedTime != null)
        (
          's-time',
          TaskFormat.time(context, suggestedTime),
          scheme.primary,
          useTime,
          onToggleTime,
        ),
    ];
    const stagger = Duration(milliseconds: 40);
    var i = 0;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (kind, icon, label, color) in labels)
          Entrance(
            key: ValueKey(kind),
            delay: stagger * i++,
            scale: .92,
            child: Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(icon, size: 16, color: color ?? scheme.primary),
              label: Text(label),
            ),
          ),
        // Suggestions only apply when tapped
        for (final (kind, label, color, selected, onTap) in suggestions)
          Entrance(
            key: ValueKey(kind),
            delay: stagger * i++,
            scale: .92,
            child: FilterChip(
              visualDensity: VisualDensity.compact,
              tooltip: l10n.suggestion,
              avatar: selected
                  ? null
                  : Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: onTint(context, color),
                    ),
              label: Text(label),
              selected: selected,
              onSelected: (_) {
                AppHaptics.selection();
                onTap();
              },
            ),
          ),
        if (pieces > 1)
          Entrance(
            key: const ValueKey('split'),
            delay: stagger * i++,
            scale: .92,
            child: ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                Icons.call_split_rounded,
                size: 16,
                color: scheme.primary,
              ),
              label: Text(l10n.splitIntoTasks(pieces)),
              onPressed: onSplit,
            ),
          ),
        if (labels.isNotEmpty)
          Entrance(
            key: const ValueKey('ignore'),
            delay: stagger * i++,
            scale: .92,
            child: ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.close_rounded, size: 16),
              label: Text(l10n.keepAsText),
              onPressed: onIgnore,
            ),
          ),
      ],
    );
  }
}

/// "You already have …" with a way to open that task instead
class _DuplicateNote extends StatelessWidget {
  const _DuplicateNote({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpace.xs, top: 4),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.info_outline_rounded,
              size: AppIcon.sm,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              context.l10n.duplicateHint(task.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => TaskEditorSheet.show(context, task.id),
            child: Text(context.l10n.open),
          ),
        ],
      ),
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
