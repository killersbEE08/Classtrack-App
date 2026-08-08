import 'dart:math' as math;

/// Actionable attendance guidance derived from counts + a target percentage.
class AttendanceAdvice {
  /// Current attendance percentage (0–100).
  final double percent;

  /// How many upcoming classes you can still miss and stay at/above target.
  /// 0 when you're exactly at the limit or already below it.
  final int canSkip;

  /// How many consecutive upcoming classes you must attend to reach the
  /// target. 0 when already on track.
  final int mustAttend;

  /// True when currently at/above target.
  final bool onTrack;

  /// True when the target can't be reached by attending alone (target ≥ 100%
  /// while already having missed a class).
  final bool unreachable;

  const AttendanceAdvice({
    required this.percent,
    required this.canSkip,
    required this.mustAttend,
    required this.onTrack,
    this.unreachable = false,
  });
}

/// Computes safe-skips / must-attend for a target percentage.
///
/// [attended] = classes present, [held] = classes that counted (present +
/// absent; cancelled classes are excluded upstream), [target] = 0–100.
AttendanceAdvice attendanceAdvice({
  required int attended,
  required int held,
  required double target,
}) {
  if (held <= 0) {
    return const AttendanceAdvice(
        percent: 0, canSkip: 0, mustAttend: 0, onTrack: true);
  }
  final percent = attended * 100.0 / held;
  if (percent >= target) {
    // Largest x with attended / (held + x) >= target/100.
    final maxHeld = target <= 0 ? double.infinity : attended * 100.0 / target;
    final canSkip = maxHeld.isFinite ? (maxHeld - held).floor() : 9999;
    return AttendanceAdvice(
      percent: percent,
      canSkip: math.max(0, canSkip),
      mustAttend: 0,
      onTrack: true,
    );
  }
  // Below target: smallest n with (attended + n) / (held + n) >= target/100.
  final denom = 100.0 - target;
  if (denom <= 0) {
    return AttendanceAdvice(
        percent: percent,
        canSkip: 0,
        mustAttend: 0,
        onTrack: false,
        unreachable: true);
  }
  final n = ((target * held - 100.0 * attended) / denom).ceil();
  return AttendanceAdvice(
    percent: percent,
    canSkip: 0,
    mustAttend: math.max(0, n),
    onTrack: false,
  );
}

/// Severity of an attendance situation for a single subject, used to decide
/// whether (and how loudly) to nudge the student.
enum AttendanceRiskLevel {
  /// No data / no upcoming classes to reason about.
  none,

  /// Comfortably above target with room to skip.
  safe,

  /// Exactly at the target — one more miss drops below it.
  warning,

  /// On target now, but skipping the upcoming class(es) drops below target.
  danger,

  /// Already below target.
  recover,
}

/// A proactive, human-readable attendance nudge for one subject. Pure and
/// side-effect free so it can be unit-tested and reused by the notification
/// scheduler. Built on top of [attendanceAdvice], plus a look-ahead at the
/// classes scheduled in the near future ([upcomingCount], e.g. tomorrow's).
class AttendanceRiskAlert {
  final String subjectName;
  final AttendanceRiskLevel level;

  /// Current attendance percentage (0–100).
  final double currentPercent;

  /// Percentage the student would have if they miss all [upcomingCount]
  /// upcoming classes and attend nothing else.
  final double percentIfSkipped;

  /// Number of upcoming classes considered in the look-ahead window.
  final int upcomingCount;

  /// Safe skips still available while staying at/above target (0 when none).
  final int canSkip;

  /// Consecutive classes that must be attended to climb back to target.
  final int mustAttend;

  /// A ready-to-show, one-line message describing the situation.
  final String message;

  const AttendanceRiskAlert({
    required this.subjectName,
    required this.level,
    required this.currentPercent,
    required this.percentIfSkipped,
    required this.upcomingCount,
    required this.canSkip,
    required this.mustAttend,
    required this.message,
  });

  bool get isActionable =>
      level == AttendanceRiskLevel.danger ||
      level == AttendanceRiskLevel.recover;
}

/// Computes a proactive attendance nudge for a subject.
///
/// [attended]/[held] are the subject's present/counted classes, [target] is the
/// desired percentage (0–100), and [upcomingCount] is how many of this
/// subject's classes fall in the look-ahead window (e.g. the number scheduled
/// tomorrow). The result classifies the situation and produces a message:
///  • already below target      → recover  ("attend N in a row")
///  • skipping upcoming < target → danger   ("skip tomorrow's X and you fall…")
///  • at the edge (canSkip == 0) → warning  ("right on your target")
///  • otherwise                  → safe     ("you can skip N more")
AttendanceRiskAlert attendanceRiskAlert({
  required String subjectName,
  required int attended,
  required int held,
  required double target,
  required int upcomingCount,
}) {
  final advice = attendanceAdvice(attended: attended, held: held, target: target);
  final current = advice.percent;

  if (held <= 0 && upcomingCount <= 0) {
    return AttendanceRiskAlert(
      subjectName: subjectName,
      level: AttendanceRiskLevel.none,
      currentPercent: 0,
      percentIfSkipped: 0,
      upcomingCount: upcomingCount,
      canSkip: 0,
      mustAttend: 0,
      message: 'No attendance data yet for $subjectName.',
    );
  }

  final projectedHeld = held + (upcomingCount < 0 ? 0 : upcomingCount);
  final percentIfSkipped =
      projectedHeld <= 0 ? 0.0 : attended * 100.0 / projectedHeld;

  final t = target.toStringAsFixed(0);

  // Already below target: recovery guidance takes precedence.
  if (!advice.onTrack) {
    final msg = advice.unreachable
        ? '$subjectName is at ${current.toStringAsFixed(0)}% — below your $t% target and can’t reach it by attending alone.'
        : 'Attend the next ${advice.mustAttend} $subjectName class${advice.mustAttend == 1 ? '' : 'es'} in a row to get back to $t%.';
    return AttendanceRiskAlert(
      subjectName: subjectName,
      level: AttendanceRiskLevel.recover,
      currentPercent: current,
      percentIfSkipped: percentIfSkipped,
      upcomingCount: upcomingCount,
      canSkip: 0,
      mustAttend: advice.mustAttend,
      message: msg,
    );
  }

  // On target, but skipping the upcoming class(es) would drop below it.
  if (upcomingCount > 0 && percentIfSkipped < target) {
    return AttendanceRiskAlert(
      subjectName: subjectName,
      level: AttendanceRiskLevel.danger,
      currentPercent: current,
      percentIfSkipped: percentIfSkipped,
      upcomingCount: upcomingCount,
      canSkip: advice.canSkip,
      mustAttend: 0,
      message: upcomingCount == 1
          ? 'Skip tomorrow’s $subjectName and you fall to ${percentIfSkipped.toStringAsFixed(0)}% — below your $t% target.'
          : 'Miss tomorrow’s $upcomingCount $subjectName classes and you fall to ${percentIfSkipped.toStringAsFixed(0)}% — below your $t% target.',
    );
  }

  // On target and right at the edge — no room to skip.
  if (advice.canSkip <= 0) {
    return AttendanceRiskAlert(
      subjectName: subjectName,
      level: AttendanceRiskLevel.warning,
      currentPercent: current,
      percentIfSkipped: percentIfSkipped,
      upcomingCount: upcomingCount,
      canSkip: 0,
      mustAttend: 0,
      message: '$subjectName is right on your $t% target — don’t miss the next one.',
    );
  }

  // Comfortably safe.
  return AttendanceRiskAlert(
    subjectName: subjectName,
    level: AttendanceRiskLevel.safe,
    currentPercent: current,
    percentIfSkipped: percentIfSkipped,
    upcomingCount: upcomingCount,
    canSkip: advice.canSkip,
    mustAttend: 0,
    message:
        'You can skip ${advice.canSkip} more $subjectName class${advice.canSkip == 1 ? '' : 'es'} and stay ≥ $t%.',
  );
}

/// Projects month-end spend by extrapolating the current daily rate across the
/// whole month. Returns [spentSoFar] unchanged on the first day boundary.
double projectedMonthlySpend({
  required double spentSoFar,
  required DateTime now,
}) {
  final dayOfMonth = now.day;
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  if (dayOfMonth <= 0 || spentSoFar <= 0) return spentSoFar;
  return spentSoFar / dayOfMonth * daysInMonth;
}
