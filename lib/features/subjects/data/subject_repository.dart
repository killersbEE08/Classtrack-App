import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/subject.dart';

/// CRUD for users/{uid}/subjects.
class SubjectRepository {
  final FirebaseFirestore _db;
  final String uid;

  SubjectRepository({required FirebaseFirestore db, required this.uid})
      : _db = db;

  CollectionReference<Map<String, dynamic>> get _col => _db
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.subjectsCollection);

  Stream<List<Subject>> watchSubjects() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs
              .map((d) => Subject.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<Subject?> watchSubject(String id) {
    return _col.doc(id).snapshots().map(
          (snap) => snap.exists ? Subject.fromMap(snap.id, snap.data()!) : null,
        );
  }

  Future<String> create(Subject subject) async {
    final ref = await _col.add(subject.toMap());
    return ref.id;
  }

  /// One-shot read of all subjects (used by import to reuse existing subjects
  /// instead of creating duplicates on re-import).
  Future<List<Subject>> getAll() async {
    final snap = await _col.get();
    return snap.docs.map((d) => Subject.fromMap(d.id, d.data())).toList();
  }

  /// Create with a known id (used by AI import batch writes).
  Future<void> setWithId(String id, Subject subject) =>
      _col.doc(id).set(subject.toMap());

  Future<void> update(Subject subject) =>
      _col.doc(subject.id).set(subject.toMap(), SetOptions(merge: true));

  /// Adjust attendance counters safely (never below 0). Only present/absent
  /// count toward the percentage; cancelled is tracked separately.
  ///
  /// Offline-safe: a `runTransaction` here would need a live server connection
  /// and silently fail to apply while offline (the reason quick Present/Absent
  /// taps sometimes "didn't register" or landed late). Instead we read the
  /// current counters cache-first (instant offline) and write them back with a
  /// plain merge `set`, which the SDK applies to the local cache immediately
  /// and syncs to the server when connectivity returns.
  Future<void> adjust(String id,
      {int attendedDelta = 0,
      int absentDelta = 0,
      int cancelledDelta = 0}) async {
    final ref = _col.doc(id);
    final data = await _readCounters(ref);
    final curAttended = (data['attended'] as num?)?.toInt() ?? 0;
    // Migrate legacy docs that only stored 'held'.
    final curAbsent = (data['absent'] as num?)?.toInt() ??
        (((data['held'] as num?)?.toInt() ?? curAttended) - curAttended)
            .clamp(0, 100000);
    final curCancelled = (data['cancelled'] as num?)?.toInt() ?? 0;

    var attended = curAttended + attendedDelta;
    var absent = curAbsent + absentDelta;
    var cancelled = curCancelled + cancelledDelta;
    if (attended < 0) attended = 0;
    if (absent < 0) absent = 0;
    if (cancelled < 0) cancelled = 0;

    await ref.set(
        {
          'attended': attended,
          'absent': absent,
          'held': attended + absent,
          'cancelled': cancelled,
        },
        SetOptions(merge: true));
  }

  /// Reads a subject's counter map without forcing a server round-trip. The
  /// subject doc is almost always already cached (it is live-streamed by
  /// [watchSubjects]), so this resolves instantly even offline.
  Future<Map<String, dynamic>> _readCounters(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      return cached.data() ?? <String, dynamic>{};
    } catch (_) {
      try {
        return (await ref.get()).data() ?? <String, dynamic>{};
      } catch (_) {
        return <String, dynamic>{};
      }
    }
  }

  /// Directly set the counters (from the manual edit dialog).
  Future<void> setAttendance(String id, int attended, int absent,
      {int? cancelled}) {
    final a = attended < 0 ? 0 : attended;
    final b = absent < 0 ? 0 : absent;
    final map = <String, dynamic>{'attended': a, 'absent': b, 'held': a + b};
    if (cancelled != null) map['cancelled'] = cancelled < 0 ? 0 : cancelled;
    return _col.doc(id).set(map, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    // Delete nested sessions + attendance first.
    final sessions =
        await _col.doc(id).collection(AppConstants.sessionsCollection).get();
    for (final s in sessions.docs) {
      await s.reference.delete();
    }
    final attendance =
        await _col.doc(id).collection(AppConstants.attendanceCollection).get();
    for (final a in attendance.docs) {
      await a.reference.delete();
    }
    await _col.doc(id).delete();
  }

  String newId() => _col.doc().id;
}
