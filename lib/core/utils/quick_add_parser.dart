import 'package:flutter/material.dart' show TimeOfDay;

import '../../features/tasks/domain/entities/task.dart';
import 'date_time_utils.dart';

/// What [parseQuickAdd] found in a task title.
class QuickAdd {
  /// The title with the recognised words taken out.
  final String title;
  final DateTime? date;
  final TimeOfDay? time;
  final TaskPriority? priority;
  final String? category;

  const QuickAdd({
    required this.title,
    this.date,
    this.time,
    this.priority,
    this.category,
  });

  bool get hasMatches =>
      date != null || time != null || priority != null || category != null;
}

class _Span {
  final int start;
  final int end;

  const _Span(this.start, this.end);
}

const _weekdays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const _numberWords = {'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3};

// A word that isn't followed by an apostrophe, so "today's report" is left
// alone.
const _end = r"(?!['’]\w)\b";

/// Picks dates, times, priorities and tags out of a quick-add title, e.g.
/// `Call Sam tomorrow at 5pm #personal !high`.
///
/// Understands: today, tonight, tomorrow, weekday names (optionally with
/// "next"), "in 3 days", "next week", times like 5pm / 5:30 pm / at 17:00 /
/// noon, `!high` `!medium` `!low` and `#tag`.
QuickAdd parseQuickAdd(
  String input, {
  required DateTime now,
  List<String> categories = const [],
}) {
  final spans = <_Span>[];
  final today = dateOnly(now);
  DateTime? date;
  TimeOfDay? time;
  TaskPriority? priority;
  String? category;

  RegExpMatch? find(String pattern) {
    final match = RegExp(pattern, caseSensitive: false).firstMatch(input);
    if (match != null) spans.add(_Span(match.start, match.end));
    return match;
  }

  final tag = find(r'(?:^|\s)#([\w-]+)');
  if (tag != null) {
    final raw = tag.group(1)!;
    category = categories.firstWhere(
      (c) => c.toLowerCase() == raw.toLowerCase(),
      orElse: () => raw[0].toUpperCase() + raw.substring(1),
    );
  }

  final bang = find(r'(?:^|\s)!(high|urgent|medium|med|normal|low)\b');
  if (bang != null) {
    priority = switch (bang.group(1)!.toLowerCase()) {
      'high' || 'urgent' => TaskPriority.high,
      'low' => TaskPriority.low,
      _ => TaskPriority.medium,
    };
  }

  final relative = find(
    r'\b(?:on\s+|by\s+|due\s+)?(today|tonight|tomorrow|tmrw)'
    '$_end',
  );
  if (relative != null) {
    final word = relative.group(1)!.toLowerCase();
    date = word == 'today' || word == 'tonight' ? today : addDays(today, 1);
    if (word == 'tonight') time = const TimeOfDay(hour: 20, minute: 0);
  }

  if (date == null) {
    final weekday = find(
      r'\b(?:on\s+|by\s+|due\s+)?(next\s+)?'
      '(${_weekdays.join('|')})$_end',
    );
    if (weekday != null) {
      final target = _weekdays.indexOf(weekday.group(2)!.toLowerCase()) + 1;
      var delta = (target - now.weekday + 7) % 7;
      if (delta == 0 && weekday.group(1) != null) delta = 7;
      date = addDays(today, delta);
    }
  }

  if (date == null) {
    final inDays = find(
      r'\bin\s+(\d{1,3}|a|an|one|two|three)\s+(days?|weeks?)\b',
    );
    if (inDays != null) {
      final amount =
          _numberWords[inDays.group(1)!.toLowerCase()] ??
          int.parse(inDays.group(1)!);
      final perUnit = inDays.group(2)!.toLowerCase().startsWith('w') ? 7 : 1;
      date = addDays(today, amount * perUnit);
    }
  }

  if (date == null && find(r'\bnext\s+week\b') != null) {
    date = addDays(today, 7);
  }

  final clock = find(r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b');
  if (clock != null) {
    var hour = int.parse(clock.group(1)!);
    final minute = int.tryParse(clock.group(2) ?? '0') ?? 0;
    final pm = clock.group(3)!.toLowerCase() == 'pm';
    if (hour >= 1 && hour <= 12 && minute < 60) {
      if (hour == 12) hour = 0;
      time = TimeOfDay(hour: pm ? hour + 12 : hour, minute: minute);
    }
  } else {
    final h24 = find(r'\bat\s+(\d{1,2}):(\d{2})\b');
    if (h24 != null) {
      final hour = int.parse(h24.group(1)!);
      final minute = int.parse(h24.group(2)!);
      if (hour < 24 && minute < 60) {
        time = TimeOfDay(hour: hour, minute: minute);
      }
    } else {
      final named = find(r'\b(?:at\s+)?(noon|midnight)\b');
      if (named != null) {
        time = named.group(1)!.toLowerCase() == 'noon'
            ? const TimeOfDay(hour: 12, minute: 0)
            : const TimeOfDay(hour: 0, minute: 0);
      }
    }
  }

  return QuickAdd(
    title: _strip(input, spans),
    date: date,
    time: time,
    priority: priority,
    category: category,
  );
}

String _strip(String input, List<_Span> spans) {
  if (spans.isEmpty) return input.trim();

  // Merge overlapping matches, then cut them out back to front.
  final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <_Span>[sorted.first];
  for (final span in sorted.skip(1)) {
    final last = merged.last;
    if (span.start <= last.end) {
      merged[merged.length - 1] = _Span(
        last.start,
        span.end > last.end ? span.end : last.end,
      );
    } else {
      merged.add(span);
    }
  }
  var text = input;
  for (final span in merged.reversed) {
    text = text.replaceRange(span.start, span.end, ' ');
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Words left dangling at the end once the date or time is gone.
  text = text.replaceFirst(
    RegExp(r'\s+(at|on|by|due|for|in)$', caseSensitive: false),
    '',
  );
  return text.trim();
}
