import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_time_utils.dart';

/// The day picked on the calendar. The add button uses it as the due date.
final calendarDayProvider = NotifierProvider<CalendarDay, DateTime>(
  CalendarDay.new,
);

class CalendarDay extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void select(DateTime day) => state = dateOnly(day);
}
