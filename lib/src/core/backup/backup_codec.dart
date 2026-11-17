import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../data/local/database/app_database.dart';
import '../../data/local/database/converters.dart';

/// Why a file couldn't be restored. Nothing is written before a backup has
/// been read in full, so the user's data is untouched either way.
enum BackupError {
  /// Not a backup, cut short, or damaged
  unreadable,

  /// Made by a newer version of the app
  tooNew,
}

class BackupException implements Exception {
  const BackupException(this.error, [this.detail]);

  final BackupError error;
  final Object? detail;

  @override
  String toString() => 'BackupException($error, $detail)';
}

/// Everything a backup holds: lists, tasks (open and done) and the activity
/// history. Deleted rows waiting for Undo are left out.
class BackupData {
  const BackupData({
    required this.createdAt,
    required this.lists,
    required this.tasks,
    required this.activity,
    this.schema = 0,
    this.appVersion,
  });

  final DateTime createdAt;
  final List<TaskList> lists;
  final List<Task> tasks;
  final List<ActivityDay> activity;

  /// Database schema it was taken from (informational)
  final int schema;
  final String? appVersion;

  /// Top-level tasks, as the user counts them
  int get taskCount => tasks.where((t) => t.parentId == null).length;

  int get openCount =>
      tasks.where((t) => t.parentId == null && !t.isDone).length;

  bool get isEmpty => lists.isEmpty && tasks.isEmpty;
}

/// `.todobackup`: gzip-compressed JSON.
///
/// Days (due dates, activity) are stored as `yyyy-MM-dd` and moments as UTC
/// ISO-8601, so a backup made in one time zone restores the same tasks on
/// the same days in another — and on the other platform. Fields missing
/// from an older backup take their defaults; fields this version doesn't
/// know are ignored.
class BackupCodec {
  BackupCodec._();

  static const format = 'todobackup';
  static const extension = 'todobackup';

  /// Bump when old apps could misread new backups
  static const version = 1;

  static Uint8List encode(BackupData data) {
    final json = {
      'format': format,
      'version': version,
      'schema': data.schema,
      if (data.appVersion != null) 'app': data.appVersion,
      'createdAt': _instant(data.createdAt),
      'lists': [for (final l in data.lists) _list(l)],
      'tasks': [for (final t in data.tasks) _task(t)],
      'activity': [
        for (final a in data.activity)
          {'day': _date(a.day), 'count': a.completedCount},
      ],
    };
    return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(json))));
  }

  /// Reads a backup completely, or throws [BackupException]
  static BackupData decode(List<int> bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(gzip.decode(bytes)));
    } on Object catch (e) {
      // FormatException, gzip errors (FileSystemException / ZLib…)
      throw BackupException(BackupError.unreadable, e);
    }
    if (json is! Map<String, Object?> || json['format'] != format) {
      throw const BackupException(BackupError.unreadable, 'not a backup');
    }
    final version = json['version'];
    if (version is! int) {
      throw const BackupException(BackupError.unreadable, 'no version');
    }
    if (version > BackupCodec.version) {
      throw BackupException(BackupError.tooNew, version);
    }
    try {
      return BackupData(
        createdAt: _parseInstant(json['createdAt'])!,
        schema: json['schema'] as int? ?? 0,
        appVersion: json['app'] as String?,
        lists: [for (final l in _maps(json['lists'])) _parseList(l)],
        tasks: [for (final t in _maps(json['tasks'])) _parseTask(t)],
        activity: [
          for (final a in _maps(json['activity']))
            ActivityDay(
              day: _parseDate(a['day'])!,
              completedCount: a['count']! as int,
            ),
        ],
      );
    } on Object catch (e) {
      // Missing or mistyped fields: TypeError, FormatException…
      throw BackupException(BackupError.unreadable, e);
    }
  }

  // ------------------------------------------------------------- encoding

  static Map<String, Object?> _list(TaskList l) => {
    'id': l.id,
    'name': l.name,
    'color': l.colorValue,
    'order': l.sortOrder,
    'createdAt': _instant(l.createdAt),
    'updatedAt': _instant(l.updatedAt),
  };

  static Map<String, Object?> _task(Task t) => {
    'id': t.id,
    'list': ?t.listId,
    'parent': ?t.parentId,
    'title': t.title,
    'note': ?t.note,
    if (t.dueDate case final due?) 'due': _date(due),
    'time': ?t.dueTime,
    'priority': t.priority,
    'done': t.isDone,
    if (t.doneAt case final at?) 'doneAt': _instant(at),
    'rrule': ?t.rrule,
    if (t.reminders.isNotEmpty) 'reminders': t.reminderOffsets,
    if (t.alarm) 'alarm': true,
    'estimate': ?t.estimateMinutes,
    'order': t.sortOrder,
    'createdAt': _instant(t.createdAt),
    'updatedAt': _instant(t.updatedAt),
  };

  static String _instant(DateTime at) => at.toUtc().toIso8601String();

  static String _date(DateTime day) => const LocalDateConverter().toSql(day);

  // ------------------------------------------------------------- decoding

  static List<Map<String, Object?>> _maps(Object? value) => [
    for (final item in (value as List<Object?>?) ?? const [])
      item! as Map<String, Object?>,
  ];

  static TaskList _parseList(Map<String, Object?> l) => TaskList(
    id: l['id']! as String,
    name: l['name']! as String,
    colorValue: l['color']! as int,
    sortOrder: (l['order']! as num).toDouble(),
    createdAt: _parseInstant(l['createdAt'])!,
    updatedAt: _parseInstant(l['updatedAt'])!,
  );

  static Task _parseTask(Map<String, Object?> t) => Task(
    id: t['id']! as String,
    listId: t['list'] as String?,
    parentId: t['parent'] as String?,
    title: t['title']! as String,
    note: t['note'] as String?,
    dueDate: _parseDate(t['due']),
    dueTime: t['time'] as int?,
    priority: t['priority'] as int? ?? 0,
    isDone: t['done'] as bool? ?? false,
    doneAt: _parseInstant(t['doneAt']),
    rrule: t['rrule'] as String?,
    reminders: ReminderOffsets.format([
      for (final o in (t['reminders'] as List<Object?>?) ?? const []) o! as int,
    ]),
    alarm: t['alarm'] as bool? ?? false,
    estimateMinutes: t['estimate'] as int?,
    sortOrder: (t['order'] as num? ?? 0).toDouble(),
    createdAt: _parseInstant(t['createdAt'])!,
    updatedAt: _parseInstant(t['updatedAt'])!,
  );

  static DateTime? _parseInstant(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  static DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value as String;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw FormatException('Bad date', text);
    }
    return const LocalDateConverter().fromSql(text);
  }
}
