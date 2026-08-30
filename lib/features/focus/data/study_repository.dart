import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_parsing.dart';
import '../domain/study_session.dart';

/// CRUD for users/{uid}/studySessions.
class StudyRepository {
  final FirebaseFirestore _db;
  final String uid;

  StudyRepository({required FirebaseFirestore db, required this.uid})
      : _db = db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('studySessions');

  Stream<List<StudySession>> watchSessions() {
    return _col.snapshots().map((snap) {
      final list = parseDocsSafely(snap.docs, StudySession.fromMap,
          context: 'studySessions');
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    });
  }

  Future<void> add(StudySession session) => _col.add(session.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}
