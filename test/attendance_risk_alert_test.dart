import 'package:classtrack/features/insights/domain/insight_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the pure attendance risk classifier that powers the Pro
/// evening-before nudge. Each branch (safe / warning / danger / recover / none)
/// is exercised against a 75% target.
void main() {
  const target = 75.0;

  AttendanceRiskAlert alert(int attended, int held, {int upcoming = 1}) =>
      attendanceRiskAlert(
        subjectName: 'DBMS',
        attended: attended,
        held: held,
        target: target,
        upcomingCount: upcoming,
      );

  group('attendanceRiskAlert', () {
    test('no data and no upcoming classes -> none', () {
      final a = alert(0, 0, upcoming: 0);
      expect(a.level, AttendanceRiskLevel.none);
      expect(a.isActionable, isFalse);
    });

    test('already below target -> recover with must-attend count', () {
      // 6/10 = 60% < 75%.
      final a = alert(6, 10);
      expect(a.level, AttendanceRiskLevel.recover);
      expect(a.currentPercent, closeTo(60, 0.001));
      expect(a.mustAttend, greaterThan(0));
      expect(a.isActionable, isTrue);
    });

    test('on target but skipping tomorrow drops below -> danger', () {
      // 3/4 = 75% (exactly on target). Skipping the 1 upcoming class -> 3/5 =
      // 60% < 75%, so this is a danger.
      final a = alert(3, 4, upcoming: 1);
      expect(a.level, AttendanceRiskLevel.danger);
      expect(a.currentPercent, closeTo(75, 0.001));
      expect(a.percentIfSkipped, closeTo(60, 0.001));
      expect(a.isActionable, isTrue);
      expect(a.message.toLowerCase(), contains('below'));
    });

    test('comfortably above target -> safe with skip budget', () {
      // 19/20 = 95%. Skipping 1 -> 19/21 ≈ 90.5% still ≥ 75%, so it is safe and
      // reports how many can still be skipped.
      final a = alert(19, 20, upcoming: 1);
      expect(a.level, AttendanceRiskLevel.safe);
      expect(a.canSkip, greaterThan(0));
      expect(a.isActionable, isFalse);
    });

    test('right on the edge with no skip room -> warning', () {
      // 3/4 = 75% on target, but with NO upcoming class the danger branch can't
      // fire; canSkip is 0 at exactly the target, so it is a warning.
      final a = alert(3, 4, upcoming: 0);
      expect(a.level, AttendanceRiskLevel.warning);
      expect(a.canSkip, 0);
    });

    test('percentIfSkipped accounts for every upcoming class', () {
      // 8/10 = 80%. Skipping 2 upcoming -> 8/12 ≈ 66.7% < 75% -> danger.
      final a = alert(8, 10, upcoming: 2);
      expect(a.percentIfSkipped, closeTo(66.666, 0.01));
      expect(a.level, AttendanceRiskLevel.danger);
      expect(a.upcomingCount, 2);
    });
  });
}
