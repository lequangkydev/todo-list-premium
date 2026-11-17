import '../date_parser/quick_add_parser.dart';

/// Something that understands task text. Tier 0 ([RuleBasedProvider]) runs
/// everywhere with plain rules; later tiers (OS models, a downloaded LLM)
/// implement the same contract and are tried first when available.
///
/// Providers only ever return text. Turning words into dates is the job of
/// [QuickAddParser] alone, so a model can never invent a date.
abstract interface class AiProvider {
  /// Short id for logs and settings
  String get id;

  /// Splits a brain dump into one string per task. Dates stay in the text
  /// for the parser to read. Returns a single element when the text is one
  /// task.
  Future<List<String>> splitTasks(String text);

  /// Steps for doing [title]; empty when this provider can't help
  Future<List<String>> breakDown(String title);
}

/// Tier 0: deterministic rules, no model, works offline on every phone.
class RuleBasedProvider implements AiProvider {
  RuleBasedProvider({QuickAddParser? parser, DateTime Function()? clock})
    : _parser = parser ?? QuickAddParser(),
      _clock = clock ?? DateTime.now;

  final QuickAddParser _parser;
  final DateTime Function() _clock;

  @override
  String get id => 'rules';

  /// "- ", "• ", "1. ", "2) ", "[ ] " at the start of a line
  static final _bullet = RegExp(
    r'^\s*(?:[-*•+–]|\d{1,2}[.)]|\[\s?[xX]?\s?\])\s+',
  );

  /// Joiners that only split a single line when every piece is scheduled:
  /// "họp 9h, gọi khách 14h" is two tasks, "mua sữa, trứng" is one
  static final _soft = RegExp(
    r'\s*,\s*|\s+(?:và|va|rồi|roi|and|then)\s+',
    caseSensitive: false,
  );

  @override
  Future<List<String>> splitTasks(String text) async {
    final lines = [
      for (final line in text.split(RegExp(r'[\n;]')))
        if (line.replaceFirst(_bullet, '').trim() case final t
            when t.isNotEmpty)
          t,
    ];
    if (lines.length != 1) {
      return lines;
    }
    final pieces = [
      for (final p in lines.single.split(_soft))
        if (p.trim().isNotEmpty) p.trim(),
    ];
    if (pieces.length < 2) {
      return lines;
    }
    final now = _clock();
    final scheduled = pieces.every((p) {
      final r = _parser.parse(p, now);
      // Each piece carries its own date or time
      return r.hasSchedule || r.time != null;
    });
    return scheduled ? pieces : lines;
  }

  @override
  Future<List<String>> breakDown(String title) async => const [];
}
