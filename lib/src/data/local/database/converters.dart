import 'package:drift/drift.dart';

/// Wall-clock date (no time zone): stored as `yyyy-MM-dd` so a task due on
/// the 14th stays on the 14th when the user changes time zone.
class LocalDateConverter extends TypeConverter<DateTime, String> {
  const LocalDateConverter();

  @override
  DateTime fromSql(String fromDb) {
    final parts = fromDb.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  @override
  String toSql(DateTime value) =>
      '${_pad(value.year, 4)}-${_pad(value.month)}-${_pad(value.day)}';
}

/// Reminder offsets (minutes) stored as `0,60`: sorted, no duplicates
class ReminderOffsetsConverter extends TypeConverter<List<int>, String> {
  const ReminderOffsetsConverter();

  @override
  List<int> fromSql(String fromDb) => normalize([
    for (final part in fromDb.split(',')) ?int.tryParse(part.trim()),
  ]);

  @override
  String toSql(List<int> value) => normalize(value).join(',');

  static List<int> normalize(Iterable<int> offsets) => ({
    for (final o in offsets)
      if (o >= 0) o,
  }.toList()..sort());
}

String _pad(int value, [int width = 2]) => value.toString().padLeft(width, '0');
