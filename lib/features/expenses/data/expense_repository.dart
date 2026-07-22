import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/expense.dart';

/// CRUD for users/{uid}/expenses.
class ExpenseRepository {
  final FirebaseFirestore _db;
  final String uid;

  ExpenseRepository({required FirebaseFirestore db, required this.uid})
      : _db = db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('expenses');

  Stream<List<Expense>> watchExpenses() {
    return _col.snapshots().map((snap) {
      final list =
          snap.docs.map((d) => Expense.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> add(Expense e) => _col.add(e.toMap());

  Future<void> update(Expense e) =>
      _col.doc(e.id).set(e.toMap(), SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();
}
