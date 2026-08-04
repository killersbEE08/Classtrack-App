import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum AttendanceStatus { present, absent, cancelled, unmarked }

extension AttendanceStatusX on AttendanceStatus {
  String get label => switch (this) {
        AttendanceStatus.present => 'Present',
        AttendanceStatus.absent => 'Absent',
        AttendanceStatus.cancelled => 'Cancelled',
        AttendanceStatus.unmarked => 'Not marked',
      };

  String get wire => name; // stored as-is

  Color get color => switch (this) {
        AttendanceStatus.present => AppColors.present,
        AttendanceStatus.absent => AppColors.absent,
        AttendanceStatus.cancelled => AppColors.cancelled,
        AttendanceStatus.unmarked => AppColors.unmarked,
      };

  IconData get icon => switch (this) {
        AttendanceStatus.present => Icons.check_circle_rounded,
        AttendanceStatus.absent => Icons.cancel_rounded,
        AttendanceStatus.cancelled => Icons.event_busy_rounded,
        AttendanceStatus.unmarked => Icons.help_outline_rounded,
      };

  static AttendanceStatus parse(String? value) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AttendanceStatus.unmarked,
    );
  }
}

/// The change each of a subject's aggregate counters must undergo when a single
/// occurrence moves from [oldStatus] to [newStatus]. Pure and side-effect free
/// so it can be unit-tested and reused by the offline-safe write path (which
/// applies these as `FieldValue.increment` deltas instead of re-reading and
/// rewriting absolute totals inside a network-only transaction).
///
/// `held` is intentionally not returned: it is always `attended + absent`.
({int attended, int absent, int cancelled}) attendanceCounterDelta(
  AttendanceStatus oldStatus,
  AttendanceStatus newStatus,
) {
  int attended = 0, absent = 0, cancelled = 0;
  // Remove the old status' contribution...
  switch (oldStatus) {
    case AttendanceStatus.present:
      attended--;
      break;
    case AttendanceStatus.absent:
      absent--;
      break;
    case AttendanceStatus.cancelled:
      cancelled--;
      break;
    case AttendanceStatus.unmarked:
      break;
  }
  // ...then add the new status' contribution.
  switch (newStatus) {
    case AttendanceStatus.present:
      attended++;
      break;
    case AttendanceStatus.absent:
      absent++;
      break;
    case AttendanceStatus.cancelled:
      cancelled++;
      break;
    case AttendanceStatus.unmarked:
      break;
  }
  return (attended: attended, absent: absent, cancelled: cancelled);
}

/// One attendance mark for a subject on a date.
///
/// Stored at users/{uid}/subjects/{subjectId}/attendance/{recordId}.
/// [recordId] is the [dateId] for a whole-day / subject-level mark, or
/// "{dateId}__{slot}" for a specific class occurrence (a session). This lets a
/// subject that meets twice on the same day be marked twice — once per session.
class AttendanceRecord {
  final String id; // Firestore doc id ("yyyy-MM-dd" or "yyyy-MM-dd__0900")
  final String dateId; // "yyyy-MM-dd"
  final String slot; // session start time e.g. "09:00" ('' = subject-level)
  final String subjectId;
  final DateTime date;
  final AttendanceStatus status;
  final DateTime? markedAt;

  const AttendanceRecord({
    required this.dateId,
    this.slot = '',
    String? id,
    required this.subjectId,
    required this.date,
    required this.status,
    this.markedAt,
  }) : id = id ?? dateId;

  Map<String, dynamic> toMap() => {
        'dateId': dateId,
        'slot': slot,
        'date': Timestamp.fromDate(date),
        'status': status.wire,
        'markedAt': markedAt != null
            ? Timestamp.fromDate(markedAt!)
            : FieldValue.serverTimestamp(),
      };

  factory AttendanceRecord.fromMap(
    String docId,
    String subjectId,
    Map<String, dynamic> map,
  ) {
    // Old records were keyed purely by dateId with no 'dateId'/'slot' fields;
    // fall back to the doc id so historical data keeps working.
    return AttendanceRecord(
      id: docId,
      dateId: (map['dateId'] as String?) ?? docId,
      slot: (map['slot'] as String?) ?? '',
      subjectId: subjectId,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: AttendanceStatusX.parse(map['status'] as String?),
      markedAt: (map['markedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Aggregate attendance stats for a subject (or overall).
class AttendanceStats {
  final int present;
  final int absent;
  final int cancelled;

  const AttendanceStats({
    this.present = 0,
    this.absent = 0,
    this.cancelled = 0,
  });

  /// Classes that count toward the percentage (cancelled excluded).
  int get held => present + absent;

  double get percent => held == 0 ? 0 : (present / held) * 100.0;

  AttendanceStats operator +(AttendanceStats o) => AttendanceStats(
        present: present + o.present,
        absent: absent + o.absent,
        cancelled: cancelled + o.cancelled,
      );

  /// Bunk calculator: how many more consecutive classes can be missed while
  /// staying at or above [target] %. Returns 0 if already below target.
  int bunkableClasses(double target) {
    if (held == 0) return 0;
    if (percent < target) return 0;
    // present / (held + x) >= target/100  ->  x <= present*100/target - held
    final maxTotal = (present * 100.0) / target;
    final x = (maxTotal - held).floor();
    return x < 0 ? 0 : x;
  }

  /// If below target, how many consecutive PRESENT classes are needed to reach it.
  int classesToRecover(double target) {
    if (held == 0 || percent >= target) return 0;
    // (present + y) / (held + y) >= target/100
    final t = target / 100.0;
    if (t >= 1) return -1; // impossible to reach 100 once you've missed one
    final y = ((t * held - present) / (1 - t)).ceil();
    return y < 0 ? 0 : y;
  }
}
