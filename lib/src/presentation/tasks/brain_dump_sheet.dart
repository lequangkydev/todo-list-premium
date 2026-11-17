import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/ai/smart_suggestions.dart';
import '../../core/analytics/app_events.dart';
import '../../core/date_parser/quick_add_parser.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/task_format.dart';
import '../../shared/widgets/motion.dart';
import 'quick_add_draft.dart';

/// Type or paste several tasks at once, one per line, and see exactly what
/// will be created before adding them all.
class BrainDumpSheet extends StatefulWidget {
  const BrainDumpSheet({
    super.key,
    this.initialText = '',
    this.defaultDate,
    this.listId,
  });

  final String initialText;
  final DateTime? defaultDate;
  final String? listId;

  /// Returns true when tasks were added
  static Future<bool?> show(
    BuildContext context, {
    String initialText = '',
    DateTime? defaultDate,
    String? listId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: AppMotion.sheet(context),
      builder: (_) => BrainDumpSheet(
        initialText: initialText,
        defaultDate: defaultDate,
        listId: listId,
      ),
    );
  }

  @override
  State<BrainDumpSheet> createState() => _BrainDumpSheetState();
}

class _BrainDumpSheetState extends State<BrainDumpSheet> {
  late final _text = TextEditingController(text: widget.initialText);
  List<String> _lines = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _split();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _split() async {
    final text = _text.text;
    final lines = text.trim().isEmpty
        ? const <String>[]
        : await getIt<SmartSuggestions>().provider.splitTasks(text);
    if (mounted && _text.text == text) {
      setState(() => _lines = lines);
    }
  }

  void _remove(int index) {
    AppHaptics.selection();
    final rest = [..._lines]..removeAt(index);
    _text.text = rest.join('\n');
    setState(() => _lines = rest);
  }

  Future<void> _save() async {
    if (_saving || _lines.isEmpty) {
      return;
    }
    _saving = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final parser = quickAddParserFor(context);
    final repo = getIt<TaskRepository>();
    final now = DateTime.now();
    final ids = <String>[];
    for (final line in _lines) {
      ids.add(
        await repo.create(
          draftFromText(
            line,
            parser.parse(line, now),
            defaultDate: widget.defaultDate,
            listId: widget.listId,
          ),
        ),
      );
    }
    AppEvents.brainDumpSaved(ids.length);
    AppHaptics.light();
    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.tasksAdded(ids.length)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              for (final id in ids) {
                await repo.delete(id);
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final parser = quickAddParserFor(context);
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l10n.addMany, style: text.titleLarge),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
            child: TextField(
              controller: _text,
              autofocus: widget.initialText.isEmpty,
              minLines: 3,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _split(),
              decoration: InputDecoration(
                labelText: l10n.addMany,
                hintText: l10n.brainDumpHint,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                alignLabelWithHint: true,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              itemCount: _lines.length,
              itemBuilder: (context, i) => Entrance(
                key: ValueKey('${_lines[i]}#$i'),
                child: _PreviewRow(
                  parsed: parser.parse(_lines[i], now),
                  defaultDate: widget.defaultDate,
                  onRemove: () => _remove(i),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.xs,
              AppSpace.xl,
              AppSpace.lg,
            ),
            child: FilledButton(
              onPressed: _lines.isEmpty ? null : _save,
              child: Text(l10n.addTasks(_lines.length)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One task as it will be created: title and the schedule read from it
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.parsed,
    required this.defaultDate,
    required this.onRemove,
  });

  final QuickAddResult parsed;
  final DateTime? defaultDate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final today = getIt<DayClock>().value;
    final date = parsed.date ?? defaultDate;
    final details = [
      if (date != null) TaskFormat.day(context, date, today),
      if (parsed.date != null && parsed.time != null)
        TaskFormat.time(context, parsed.time!),
      if (parsed.recurrence != null)
        TaskFormat.recurrence(context, parsed.recurrence!),
      if (parsed.priority > 0) TaskFormat.priority(l10n, parsed.priority),
    ];
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(
        start: AppSpace.xl,
        end: AppSpace.sm,
      ),
      leading: ExcludeSemantics(
        child: Icon(
          Icons.radio_button_unchecked_rounded,
          color: parsed.priority > 0
              ? context.taskColors.priority(parsed.priority)
              : scheme.outline,
        ),
      ),
      title: Text(parsed.title),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      trailing: IconButton(
        tooltip: l10n.remove,
        icon: const Icon(Icons.close_rounded),
        onPressed: onRemove,
      ),
    );
  }
}
