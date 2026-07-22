import 'package:intl/intl.dart';

import '../../features/schedule/domain/class_session.dart';
import '../../features/subjects/domain/subject.dart';
import '../constants/app_constants.dart';

/// Builds a universal .ics (iCalendar) document from subjects + sessions.
/// Recurring weekly sessions become VEVENTs with an RRULE.
class IcsExporter {
  IcsExporter._();

  static const _weekdayRrule = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  /// [semesterStart]/[semesterEnd] bound recurring events.
  static String build({
    required List<Subject> subjects,
    required Map<String, List<ClassSession>> sessionsBySubject,
    required DateTime semesterStart,
    required DateTime semesterEnd,
  }) {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//ClassTrack//EN')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH');

    for (final subject in subjects) {
      final sessions = sessionsBySubject[subject.id] ?? const [];
      for (final s in sessions) {
        _writeEvent(buffer, subject, s, semesterStart, semesterEnd);
      }
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static void _writeEvent(
    StringBuffer b,
    Subject subject,
    ClassSession s,
    DateTime semStart,
    DateTime semEnd,
  ) {
    final DateTime firstDate;
    if (s.recurring && s.dayOfWeek != null) {
      firstDate = _firstOccurrence(semStart, s.dayOfWeek!);
    } else if (s.specificDate != null) {
      firstDate = s.specificDate!;
    } else {
      return;
    }

    final startParts = s.startTime.split(':');
    final endParts = s.endTime.split(':');
    if (startParts.length != 2 || endParts.length != 2) return;

    final dtStart = DateTime(firstDate.year, firstDate.month, firstDate.day,
        int.parse(startParts[0]), int.parse(startParts[1]));
    final dtEnd = DateTime(firstDate.year, firstDate.month, firstDate.day,
        int.parse(endParts[0]), int.parse(endParts[1]));

    final fmt = DateFormat("yyyyMMdd'T'HHmmss");
    final stamp = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(DateTime.now().toUtc());
    final uid = '${subject.id}-${s.id}@classtrack.app';

    b
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:$uid')
      ..writeln('DTSTAMP:$stamp')
      ..writeln('DTSTART:${fmt.format(dtStart)}')
      ..writeln('DTEND:${fmt.format(dtEnd)}')
      ..writeln('SUMMARY:${_escape(subject.name)}');

    if (s.room != null && s.room!.isNotEmpty) {
      b.writeln('LOCATION:${_escape(s.room!)}');
    }

    final desc = <String>[];
    if (subject.professor != null && subject.professor!.isNotEmpty) {
      desc.add('Professor: ${subject.professor}');
    }
    if (subject.classLink != null && subject.classLink!.isNotEmpty) {
      desc.add('Join: ${subject.classLink}');
    }
    if (desc.isNotEmpty) {
      b.writeln('DESCRIPTION:${_escape(desc.join("\\n"))}');
    }

    if (s.recurring && s.dayOfWeek != null) {
      final until = DateFormat("yyyyMMdd'T'235959'Z'").format(semEnd.toUtc());
      b.writeln(
          'RRULE:FREQ=WEEKLY;BYDAY=${_weekdayRrule[s.dayOfWeek!]};UNTIL=$until');
    }

    b.writeln('END:VEVENT');
  }

  static DateTime _firstOccurrence(DateTime from, int weekday0) {
    var cursor = DateTime(from.year, from.month, from.day);
    while (cursor.weekday - 1 != weekday0) {
      cursor = cursor.add(const Duration(days: 1));
    }
    return cursor;
  }

  static String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;')
      .replaceAll('\n', '\\n');

  static String fileName() =>
      '${AppConstants.appName}_schedule_${DateFormat('yyyyMMdd').format(DateTime.now())}.ics';
}
