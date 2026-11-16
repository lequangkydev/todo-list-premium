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

String _pad(int value, [int width = 2]) => value.toString().padLeft(width, '0');
