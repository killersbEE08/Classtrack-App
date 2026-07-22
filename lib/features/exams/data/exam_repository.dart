import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/exam.dart';

/// CRUD for users/{uid}/exams.
class ExamRepository {
  final FirebaseFirestore _db;
  final String uid;

  ExamRepository({required FirebaseFirestore db, required this.uid})
      : _db = db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('exams');

  Stream<List<Exam>> watchExams() {
    return _col.snapshots().map((snap) {
      final list = snap.docs.map((d) => Exam.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }

  Future<void> add(Exam exam) => _col.add(exam.toMap());

  Future<void> update(Exam exam) =>
      _col.doc(exam.id).set(exam.toMap(), SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();
}
