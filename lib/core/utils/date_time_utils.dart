import 'package:flutter/material.dart' show DayPeriod, TimeOfDay;
import 'package:intl/intl.dart';

/// Small, dependency-free helpers for the date/time handling used across the
/// app. Kept pure so they are easy to unit test.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
/// Uses UTC dates so daylight-saving changes cannot shift the result.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Parses the time strings stored on tasks. Accepts `02:00 PM`, `2:00pm`
/// and 24h `14:00`. Returns null when the text is empty or not a time.
TimeOfDay? parseTimeOfDay(String? text) {
  if (text == null) return null;
  final match = RegExp(
    r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])?\s*$',
  ).firstMatch(text);
  if (match == null) return null;

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final period = match.group(3)?.toUpperCase();
  if (minute > 59) return null;

  if (period != null) {
    if (hour < 1 || hour > 12) return null;
    if (period == 'AM') {
      hour = hour == 12 ? 0 : hour;
    } else {
      hour = hour == 12 ? 12 : hour + 12;
    }
  } else if (hour > 23) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

/// `02:00 PM` – the format tasks are stored with.
String formatTimeOfDay(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '${hour.toString().padLeft(2, '0')}:$minute $period';
}

/// `08:00` – the format used for settings values.
String formatTime24(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// Combines a calendar day with an optional time of day.
DateTime combineDateAndTime(DateTime date, TimeOfDay? time) => DateTime(
  date.year,
  date.month,
  date.day,
  time?.hour ?? 0,
  time?.minute ?? 0,
);

/// `Today`, `Tomorrow`, `Yesterday` or e.g. `Mon, Oct 5`.
String dayLabel(DateTime date, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = daysBetween(today, date);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  final sameYear = date.year == today.year;
  return DateFormat(sameYear ? 'EEE, MMM d' : 'EEE, MMM d, y').format(date);
}

String _plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

/// `In 3 hours`, `In 20 minutes`, `Overdue by 2 days`, `Due now`.
String relativeDueLabel(DateTime due, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = due.difference(current);
  final future = !diff.isNegative;
  final abs = diff.abs();

  String amount;
  if (abs.inMinutes < 1) return 'Due now';
  if (abs.inMinutes < 60) {
    amount = _plural(abs.inMinutes, 'minute');
  } else if (abs.inHours < 24) {
    amount = _plural(abs.inHours, 'hour');
  } else {
    // Calendar days, so a daylight-saving change cannot make it off by one.
    final days = daysBetween(current, due).abs();
    amount = _plural(days == 0 ? 1 : days, 'day');
  }
  return future ? 'In $amount' : 'Overdue by $amount';
}

/// `just now`, `5 minutes ago`, `2 hours ago`, `yesterday`, `3 days ago`,
/// otherwise a short date.
String timeAgo(DateTime then, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(then);
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${_plural(diff.inMinutes, 'minute')} ago';
  if (diff.inHours < 24) return '${_plural(diff.inHours, 'hour')} ago';
  final days = daysBetween(then, current);
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  return 'on ${DateFormat('MMM d, y').format(then)}';
}
