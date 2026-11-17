import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../core/focus/focus_timer.dart';
import '../local/database/app_database.dart';

/// Focus blocks the timer recorded
@lazySingleton
class FocusRepository {
  FocusRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<void> add(FocusRecord record) {
    return _db
        .into(_db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: _uuid.v4(),
            taskId: Value(record.taskId),
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            focusMinutes: record.focusMinutes,
            plannedMinutes: record.plannedMinutes,
            completed: Value(record.completed),
          ),
        );
  }

  /// Sessions started on or after [from], oldest first
  Stream<List<FocusSession>> watchSince(DateTime from) {
    return (_db.select(_db.focusSessions)
          ..where((s) => s.startedAt.isBiggerOrEqualValue(from))
          ..orderBy([(s) => OrderingTerm.asc(s.startedAt)]))
        .watch();
  }
}
