import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/task_item.dart';

/// CRUD for users/{uid}/tasks.
class TaskRepository {
  final FirebaseFirestore _db;
  final String uid;

  TaskRepository({required FirebaseFirestore db, required this.uid}) : _db = db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('tasks');

  Stream<List<TaskItem>> watchTasks() {
    return _col.snapshots().map((snap) {
      final list =
          snap.docs.map((d) => TaskItem.fromMap(d.id, d.data())).toList();
      // Sort: incomplete first, then by due date (nulls last), then priority.
      list.sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        final ad = a.dueDate, bd = b.dueDate;
        if (ad == null && bd == null) {
          return b.priority.index.compareTo(a.priority.index);
        }
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
      return list;
    });
  }

  Future<void> add(TaskItem task) => _col.add(task.toMap());

  Future<void> update(TaskItem task) =>
      _col.doc(task.id).set(task.toMap(), SetOptions(merge: true));

  Future<void> toggleDone(TaskItem task) =>
      _col.doc(task.id).set({'done': !task.done}, SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();
}
