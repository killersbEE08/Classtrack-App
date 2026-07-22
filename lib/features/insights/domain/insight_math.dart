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
    return AttendanceAdvice(
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
