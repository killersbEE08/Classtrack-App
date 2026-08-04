import 'package:classtrack/features/attendance/domain/attendance_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// The offline-safe write path applies these deltas as `FieldValue.increment`
/// values, so they must exactly balance a subject's attended/absent/cancelled
/// counters as an occurrence moves between statuses. `held` is always
/// `attended + absent`, so we assert that invariant on the returned deltas too.
void main() {
  group('attendanceCounterDelta', () {
    test('no change when status is unchanged', () {
      for (final s in AttendanceStatus.values) {
        final d = attendanceCounterDelta(s, s);
        expect(d.attended, 0);
        expect(d.absent, 0);
        expect(d.cancelled, 0);
      }
    });

    test('first mark: unmarked -> present', () {
      final d = attendanceCounterDelta(
          AttendanceStatus.unmarked, AttendanceStatus.present);
      expect(d.attended, 1);
      expect(d.absent, 0);
      expect(d.cancelled, 0);
    });

    test('first mark: unmarked -> absent', () {
      final d = attendanceCounterDelta(
          AttendanceStatus.unmarked, AttendanceStatus.absent);
      expect(d.attended, 0);
      expect(d.absent, 1);
      expect(d.cancelled, 0);
    });

    test('first mark: unmarked -> cancelled (excluded from held)', () {
      final d = attendanceCounterDelta(
          AttendanceStatus.unmarked, AttendanceStatus.cancelled);
      expect(d.attended, 0);
      expect(d.absent, 0);
      expect(d.cancelled, 1);
      // held delta = attended + absent = 0 -> cancelled never affects the %.
      expect(d.attended + d.absent, 0);
    });

    test('correction: present -> absent moves one class across', () {
      final d = attendanceCounterDelta(
          AttendanceStatus.present, AttendanceStatus.absent);
      expect(d.attended, -1);
      expect(d.absent, 1);
      expect(d.cancelled, 0);
      // held (attended + absent) is unchanged by a present<->absent flip.
      expect(d.attended + d.absent, 0);
    });

    test('correction: absent -> present moves one class back', () {
      final d = attendanceCounterDelta(
          AttendanceStatus.absent, AttendanceStatus.present);
      expect(d.attended, 1);
      expect(d.absent, -1);
      expect(d.cancelled, 0);
      expect(d.attended + d.absent, 0);
    });

    test('correction: present -> cancelled drops it out of held', () {
      final d = attendanceCounterDelta(
          AttendanceStatus.present, AttendanceStatus.cancelled);
      expect(d.attended, -1);
      expect(d.absent, 0);
      expect(d.cancelled, 1);
      // Removing a present from held lowers held by 1.
      expect(d.attended + d.absent, -1);
    });

    test('clearing: present -> unmarked rolls the counter back', () {
      final d = attendanceCounterDelta(
          AttendanceStatus.present, AttendanceStatus.unmarked);
      expect(d.attended, -1);
      expect(d.absent, 0);
      expect(d.cancelled, 0);
    });

    test('clearing: cancelled -> unmarked rolls the counter back', () {
      final d = attendanceCounterDelta(
          AttendanceStatus.cancelled, AttendanceStatus.unmarked);
      expect(d.attended, 0);
      expect(d.absent, 0);
      expect(d.cancelled, -1);
    });

    test('round-trip mark then clear nets to zero for every status', () {
      for (final s in [
        AttendanceStatus.present,
        AttendanceStatus.absent,
        AttendanceStatus.cancelled,
      ]) {
        final mark = attendanceCounterDelta(AttendanceStatus.unmarked, s);
        final clear = attendanceCounterDelta(s, AttendanceStatus.unmarked);
        expect(mark.attended + clear.attended, 0);
        expect(mark.absent + clear.absent, 0);
        expect(mark.cancelled + clear.cancelled, 0);
      }
    });
  });
}
