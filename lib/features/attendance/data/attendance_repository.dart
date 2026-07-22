import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/attendance_record.dart';

/// CRUD for users/{uid}/subjects/{subjectId}/attendance.
class AttendanceRepository {
  final FirebaseFirestore _db;
  final String uid;

  AttendanceRepository({required FirebaseFirestore db, required this.uid})
      : _db = db;

  CollectionReference<Map<String, dynamic>> _col(String subjectId) => _db
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.subjectsCollection)
      .doc(subjectId)
      .collection(AppConstants.attendanceCollection);

  DocumentReference<Map<String, dynamic>> _subjectRef(String subjectId) => _db
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.subjectsCollection)
      .doc(subjectId);

  Stream<List<AttendanceRecord>> watchForSubject(String subjectId) {
    return _col(subjectId).snapshots().map(
          (snap) => snap.docs
              .map((d) => AttendanceRecord.fromMap(d.id, subjectId, d.data()))
              .toList(),
        );
  }

  /// Set the attendance status for [subjectId] on [date] AND keep the subject's
  /// aggregate counters (attended / absent / cancelled) in sync in one atomic
  /// transaction. Passing [AttendanceStatus.unmarked] clears that day's record
  /// and rolls back its counter contribution. No-op when the status is
  /// unchanged. This is the single source of truth for per-day marking, so a
  /// class marked today stays marked (it will not "come back" on rebuild) and
  /// the overall percentage updates immediately.
  Future<void> setStatus({
    required String subjectId,
    required DateTime date,
    required AttendanceStatus status,
    String slot = '',
  }) async {
    final dateId = DateUtilsX.dateId(date);
    // A specific class occurrence gets its own record ("{dateId}__{slot}") so a
    // subject that meets twice in one day can be marked twice. A subject-level
    // mark (slot == '') keeps the legacy doc id == dateId for compatibility.
    final recordId =
        slot.isEmpty ? dateId : '${dateId}__${slot.replaceAll(':', '')}';
    final subjectRef = _subjectRef(subjectId);
    final recordRef = _col(subjectId).doc(recordId);

    await _db.runTransaction((tx) async {
      final recSnap = await tx.get(recordRef);
      final subSnap = await tx.get(subjectRef);

      final oldStatus = recSnap.exists
          ? AttendanceStatusX.parse(recSnap.data()?['status'] as String?)
          : AttendanceStatus.unmarked;
      if (oldStatus == status) return;

      final data = subSnap.data() ?? <String, dynamic>{};
      var attended = (data['attended'] as num?)?.toInt() ?? 0;
      var absent = (data['absent'] as num?)?.toInt() ?? 0;
      var cancelled = (data['cancelled'] as num?)?.toInt() ?? 0;

      // Roll back the previous status' contribution to the counters...
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
      // ...then apply the new status.
      switch (status) {
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
      if (attended < 0) attended = 0;
      if (absent < 0) absent = 0;
      if (cancelled < 0) cancelled = 0;

      tx.set(
        subjectRef,
        {
          'attended': attended,
          'absent': absent,
          'held': attended + absent,
          'cancelled': cancelled,
        },
        SetOptions(merge: true),
      );

      if (status == AttendanceStatus.unmarked) {
        tx.delete(recordRef);
      } else {
        final record = AttendanceRecord(
          id: recordId,
          dateId: dateId,
          slot: slot,
          subjectId: subjectId,
          date: DateTime(date.year, date.month, date.day),
          status: status,
          markedAt: DateTime.now(),
        );
        tx.set(recordRef, record.toMap());
      }
    });
  }

  Future<void> mark({
    required String subjectId,
    required DateTime date,
    required AttendanceStatus status,
  }) async {
    final dateId = DateUtilsX.dateId(date);
    final record = AttendanceRecord(
      dateId: dateId,
      subjectId: subjectId,
      date: DateTime(date.year, date.month, date.day),
      status: status,
      markedAt: DateTime.now(),
    );
    await _col(subjectId).doc(dateId).set(record.toMap());
  }

  Future<void> clear(String subjectId, DateTime date) =>
      _col(subjectId).doc(DateUtilsX.dateId(date)).delete();
}
