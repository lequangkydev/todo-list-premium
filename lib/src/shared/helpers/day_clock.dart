import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../core/date/dates.dart';

/// Current calendar day; ticks at midnight and when [refresh] is called (app
/// resumed), so "Today" never shows yesterday's list.
@lazySingleton
class DayClock extends ValueNotifier<DateTime> {
  DayClock() : super(Dates.today()) {
    _schedule();
  }

  Timer? _timer;

  void refresh() {
    final today = Dates.today();
    if (today != value) {
      value = today;
    }
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    final next = Dates.addDays(Dates.dateOnly(now), 1);
    _timer = Timer(next.difference(now) + const Duration(seconds: 1), refresh);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
