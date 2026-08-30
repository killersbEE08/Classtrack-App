import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date & time helpers shared across features.
class DateUtilsX {
  DateUtilsX._();

  /// Firestore-friendly date id, e.g. "2026-07-18".
  static String dateId(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(DateUtils.dateOnly(date));

  static DateTime fromDateId(String id) => DateFormat('yyyy-MM-dd').parse(id);

  static String prettyDate(DateTime date) =>
      DateFormat('EEE, d MMM').format(date);

  static String prettyFullDate(DateTime date) =>
      DateFormat('EEEE, d MMMM yyyy').format(date);

  static String monthYear(DateTime date) =>
      DateFormat('MMMM yyyy').format(date);

  /// "09:00" from a TimeOfDay.
  static String formatTime24(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Parse "HH:MM" (24h) into TimeOfDay; null on failure.
  static TimeOfDay? parseTime24(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  /// Format a "HH:MM" 24h string for display honoring locale/12h.
  static String displayTime(BuildContext context, String time24) {
    final tod = parseTime24(time24);
    if (tod == null) return time24;
    return tod.format(context);
  }

  static int minutesOfDay(String time24) {
    final tod = parseTime24(time24);
    if (tod == null) return 0;
    return tod.hour * 60 + tod.minute;
  }

  /// Fixes a 12h→24h conversion slip where an afternoon (PM) end time was
  /// mistakenly stored as its AM twin — e.g. a class ending at 1:20 PM saved
  /// as "01:20", or noon ("12:00") saved as midnight ("00:00"). Whenever the
  /// end lands at/before the start (an impossible same-day class), bumping it
  /// forward 12 hours almost always restores the intended PM time, so we do
  /// that when the result lands after the start and still inside the day.
  /// Genuinely valid sessions (end already after start) are left untouched.
  static String normalizeEndTime24(String start, String end) {
    final s = parseTime24(start);
    final e = parseTime24(end);
    if (s == null || e == null) return end;
    final startMin = s.hour * 60 + s.minute;
    final endMin = e.hour * 60 + e.minute;
    // End is not after start → likely a PM time recorded as AM. Add 12h when
    // that makes the class valid (ends after it starts, before midnight).
    if (endMin <= startMin) {
      final bumped = endMin + 12 * 60;
      if (bumped > startMin && bumped < 24 * 60) {
        final h = (bumped ~/ 60).toString().padLeft(2, '0');
        final m = (bumped % 60).toString().padLeft(2, '0');
        return '$h:$m';
      }
    }
    return end;
  }

  /// Combine a calendar date and "HH:MM" into a full DateTime.
  static DateTime combine(DateTime date, String time24) {
    final tod = parseTime24(time24) ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(date.year, date.month, date.day, tod.hour, tod.minute);
  }

  static bool isSameDay(DateTime a, DateTime b) => DateUtils.isSameDay(a, b);

  /// All dates in [start, end] inclusive that fall on the given weekday (0..6).
  static List<DateTime> datesForWeekday({
    required DateTime start,
    required DateTime end,
    required int weekday0,
  }) {
    final result = <DateTime>[];
    var cursor = DateUtils.dateOnly(start);
    final last = DateUtils.dateOnly(end);
    while (!cursor.isAfter(last)) {
      if (cursor.weekday - 1 == weekday0) result.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }
}
