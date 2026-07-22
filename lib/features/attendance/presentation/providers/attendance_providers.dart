import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../data/attendance_repository.dart';
import '../../domain/attendance_record.dart';

/// Aggregate stats for a single subject, derived from its attended/held counters.
final subjectStatsProvider =
    Provider.family<AttendanceStats, String>((ref, subjectId) {
  final subject = ref.watch(subjectsByIdProvider)[subjectId];
  if (subject == null) return const AttendanceStats();
  return AttendanceStats(
    present: subject.attended,
    absent: subject.missed,
    cancelled: subject.cancelled,
  );
});

/// Overall stats across all subjects.
final overallStatsProvider = Provider<AttendanceStats>((ref) {
  final subjects = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];
  var total = const AttendanceStats();
  for (final s in subjects) {
    total = total +
        AttendanceStats(
            present: s.attended, absent: s.missed, cancelled: s.cancelled);
  }
  return total;
});

/// Per-date attendance repository bound to the current user (null signed out).
final attendanceRepositoryProvider = Provider<AttendanceRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return AttendanceRepository(db: ref.watch(firestoreProvider), uid: uid);
});

/// Live per-date attendance records for a single subject.
final attendanceForSubjectProvider =
    StreamProvider.family<List<AttendanceRecord>, String>((ref, subjectId) {
  final repo = ref.watch(attendanceRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchForSubject(subjectId);
});

/// Canonical key for one class occurrence on a day: subject + session slot.
String attendanceOccurrenceKey(String subjectId, String slot) =>
    '$subjectId#$slot';

/// Given today's session start-times and the slots already marked today,
/// returns the next slot to mark: the first unmarked session; if every session
/// is already marked, the last one (so a re-tap corrects it rather than adding);
/// or '' when nothing is scheduled (a single subject-level record).
String nextAttendanceSlot(List<String> todaySlots, Set<String> markedSlots) {
  for (final s in todaySlots) {
    if (!markedSlots.contains(s)) return s;
  }
  return todaySlots.isEmpty ? '' : todaySlots.last;
}

/// Map of occurrence-key -> the status marked for TODAY (only entries that have
/// a record for today are present). Keyed per session occurrence so a subject
/// that meets twice today can have each class tracked independently. Drives the
/// dashboard so a class marked today disappears from the "to mark" list and
/// stays gone, while a second same-subject class remains until it too is marked.
final todayStatusProvider = Provider<Map<String, AttendanceStatus>>((ref) {
  final todayId = DateUtilsX.dateId(DateTime.now());
  final subjects = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];
  final map = <String, AttendanceStatus>{};
  for (final s in subjects) {
    final records =
        ref.watch(attendanceForSubjectProvider(s.id)).valueOrNull ?? const [];
    for (final r in records) {
      if (r.dateId == todayId && r.status != AttendanceStatus.unmarked) {
        map[attendanceOccurrenceKey(s.id, r.slot)] = r.status;
      }
    }
  }
  return map;
});

/// Attendance recorded over the last 7 days (from per-date records), for the
/// dashboard "This week" insights card.
final weeklyAttendanceProvider = Provider<AttendanceStats>((ref) {
  final now = DateTime.now();
  final weekStart =
      DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final subjects = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];
  var present = 0, absent = 0, cancelled = 0;
  for (final s in subjects) {
    final records =
        ref.watch(attendanceForSubjectProvider(s.id)).valueOrNull ?? const [];
    for (final r in records) {
      if (r.date.isBefore(weekStart)) continue;
      switch (r.status) {
        case AttendanceStatus.present:
          present++;
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
    }
  }
  return AttendanceStats(
      present: present, absent: absent, cancelled: cancelled);
});

/// Controller for adjusting attendance — both quick counters (Progress screen)
/// and per-date marking (dashboard / today's classes).
final attendanceControllerProvider = Provider<AttendanceController>((ref) {
  return AttendanceController(
    ref.watch(subjectRepositoryProvider),
    ref.watch(attendanceRepositoryProvider),
  );
});

class AttendanceController {
  final dynamic _repo; // SubjectRepository (nullable)
  final AttendanceRepository? _attendance;
  AttendanceController(this._repo, this._attendance);

  // --- Quick counter adjustments (no specific date) ---------------------------

  Future<void> markPresent(String subjectId) async =>
      _repo?.adjust(subjectId, attendedDelta: 1);

  Future<void> markAbsent(String subjectId) async =>
      _repo?.adjust(subjectId, absentDelta: 1);

  /// A cancelled class is recorded separately and does not affect the
  /// attendance percentage.
  Future<void> markCancelled(String subjectId) async =>
      _repo?.adjust(subjectId, cancelledDelta: 1);

  Future<void> adjustAttended(String subjectId, int delta) async =>
      _repo?.adjust(subjectId, attendedDelta: delta);

  Future<void> adjustAbsent(String subjectId, int delta) async =>
      _repo?.adjust(subjectId, absentDelta: delta);

  Future<void> setCounts(String subjectId, int attended, int absent,
          {int? cancelled}) async =>
      _repo?.setAttendance(subjectId, attended, absent, cancelled: cancelled);

  // --- Per-date marking (writes a dated record + reconciles counters) ---------

  /// Mark [subjectId] on [date] with [status]. Pass [AttendanceStatus.unmarked]
  /// to clear the day. Keeps the aggregate percentage in sync.
  Future<void> setForDate(
    String subjectId,
    DateTime date,
    AttendanceStatus status,
  ) async =>
      _attendance?.setStatus(
        subjectId: subjectId,
        date: date,
        status: status,
      );

  /// Mark a specific class occurrence ([slot] = the session's start time, e.g.
  /// "09:00") on [date]. Idempotent per occurrence, so marking the same class
  /// from any screen never double-counts, while two different sessions of the
  /// same subject on the same day are counted separately.
  Future<void> setForOccurrence(
    String subjectId,
    DateTime date,
    String slot,
    AttendanceStatus status,
  ) async =>
      _attendance?.setStatus(
        subjectId: subjectId,
        date: date,
        slot: slot,
        status: status,
      );
}
