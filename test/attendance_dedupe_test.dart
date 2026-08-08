import 'package:classtrack/features/attendance/domain/attendance_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for [dedupeAttendanceRecords], which fixes the "3 ticks for 2 classes"
/// (recent-attendance strip) and inflated "This week" attendance bugs by
/// collapsing duplicate / superseded attendance records.
AttendanceRecord rec({
  required String dateId,
  String slot = '',
  AttendanceStatus status = AttendanceStatus.present,
  DateTime? markedAt,
}) {
  final date = DateTime.parse(dateId);
  return AttendanceRecord(
    id: slot.isEmpty ? dateId : '${dateId}__${slot.replaceAll(':', '')}',
    dateId: dateId,
    slot: slot,
    subjectId: 'sub1',
    date: date,
    status: status,
    markedAt: markedAt,
  );
}

void main() {
  group('dedupeAttendanceRecords', () {
    test('empty stays empty', () {
      expect(dedupeAttendanceRecords(const []), isEmpty);
    });

    test('a legacy whole-day record is superseded by a per-session one', () {
      // Same class marked once via the old subject-level path (slot '') and
      // once via the per-session path (slot '11:20') -> should count ONCE.
      final out = dedupeAttendanceRecords([
        rec(dateId: '2026-08-05', slot: ''),
        rec(dateId: '2026-08-05', slot: '11:20'),
      ]);
      expect(out.length, 1);
      expect(out.single.slot, '11:20');
    });

    test('two genuine same-day sessions are both kept', () {
      final out = dedupeAttendanceRecords([
        rec(dateId: '2026-08-05', slot: '09:00'),
        rec(dateId: '2026-08-05', slot: '14:00'),
      ]);
      expect(out.length, 2);
    });

    test('exact duplicate (same day+slot) keeps the latest mark', () {
      final out = dedupeAttendanceRecords([
        rec(
            dateId: '2026-08-05',
            slot: '09:00',
            status: AttendanceStatus.absent,
            markedAt: DateTime(2026, 8, 5, 9)),
        rec(
            dateId: '2026-08-05',
            slot: '09:00',
            status: AttendanceStatus.present,
            markedAt: DateTime(2026, 8, 5, 10)),
      ]);
      expect(out.length, 1);
      expect(out.single.status, AttendanceStatus.present);
    });

    test('records on different days are all kept', () {
      final out = dedupeAttendanceRecords([
        rec(dateId: '2026-08-03', slot: '09:00'),
        rec(dateId: '2026-08-04', slot: '09:00'),
        rec(dateId: '2026-08-05', slot: '09:00'),
      ]);
      expect(out.length, 3);
    });

    test('3 records for a class marked twice collapse to 2 (the bug)', () {
      // Two real classes on two days, plus a stray legacy whole-day record on
      // one of those days -> exactly 2 after dedupe.
      final out = dedupeAttendanceRecords([
        rec(dateId: '2026-08-03', slot: '09:00'),
        rec(dateId: '2026-08-05', slot: '09:00'),
        rec(dateId: '2026-08-05', slot: ''), // legacy, superseded
      ]);
      expect(out.length, 2);
    });
  });
}
