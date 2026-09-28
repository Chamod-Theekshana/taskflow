import 'package:flutter/material.dart' show DayPeriod, TimeOfDay;
import 'package:intl/intl.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
/// Done in UTC so a daylight-saving change can't shift the result.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Monday of the week that contains [d].
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Parses the stored task times. Accepts `02:00 PM`, `2:00pm` and `14:00`.
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

/// `02:00 PM` - the format task times are stored in.
String formatTimeOfDay(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '${hour.toString().padLeft(2, '0')}:$minute $period';
}

/// `08:00` - the format used for settings values.
String formatTime24(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// `2:00 PM`
String shortTime(DateTime time) => DateFormat('h:mm a').format(time);

DateTime combineDateAndTime(DateTime date, TimeOfDay? time) => DateTime(
  date.year,
  date.month,
  date.day,
  time?.hour ?? 0,
  time?.minute ?? 0,
);

/// `Today`, `Tomorrow`, `Yesterday`, otherwise e.g. `Mon, Oct 5`.
String dayLabel(DateTime date, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = daysBetween(today, date);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  final sameYear = date.year == today.year;
  return DateFormat(sameYear ? 'EEE, MMM d' : 'EEE, MMM d, y').format(date);
}

String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

/// `In 3 hours`, `In 20 minutes`, `Overdue by 2 days`, `Due now`.
String relativeDueLabel(DateTime due, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = due.difference(current);
  final future = !diff.isNegative;
  final abs = diff.abs();

  String amount;
  if (abs.inMinutes < 1) return 'Due now';
  if (abs.inMinutes < 60) {
    amount = plural(abs.inMinutes, 'minute');
  } else if (abs.inHours < 24) {
    amount = plural(abs.inHours, 'hour');
  } else {
    final days = daysBetween(current, due).abs();
    amount = plural(days == 0 ? 1 : days, 'day');
  }
  return future ? 'In $amount' : 'Overdue by $amount';
}

/// `just now`, `5 minutes ago`, `yesterday`, `3 days ago`, `on Oct 5, 2026`.
String timeAgo(DateTime then, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(then);
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${plural(diff.inMinutes, 'minute')} ago';
  if (diff.inHours < 24) return '${plural(diff.inHours, 'hour')} ago';
  final days = daysBetween(then, current);
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  return 'on ${DateFormat('MMM d, y').format(then)}';
}

/// `today`, `yesterday`, `3 days ago`... for day-level events.
String dayAgo(DateTime then, {DateTime? now}) {
  final days = daysBetween(then, now ?? DateTime.now());
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  return 'on ${DateFormat('MMM d, y').format(then)}';
}

String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 22) return 'Good evening';
  return 'Hello';
}

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}
