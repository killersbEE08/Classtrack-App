import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_parsing.dart';
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
          parseDocsSafely(snap.docs, TaskItem.fromMap, context: 'tasks');
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

  /// One-shot read of all tasks (used by import to avoid creating duplicates
  /// on re-import).
  Future<List<TaskItem>> getAll() async {
    final snap = await _col.get();
    return parseDocsSafely(snap.docs, TaskItem.fromMap, context: 'tasks');
  }

  Future<void> update(TaskItem task) =>
      _col.doc(task.id).set(task.toMap(), SetOptions(merge: true));

  Future<void> toggleDone(TaskItem task) =>
      _col.doc(task.id).set({'done': !task.done}, SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();
}
