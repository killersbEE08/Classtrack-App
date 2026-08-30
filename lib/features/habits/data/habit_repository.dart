import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/firestore_parsing.dart';
import '../domain/habit.dart';

/// CRUD for users/{uid}/habits.
class HabitRepository {
  final FirebaseFirestore _db;
  final String uid;

  HabitRepository({required FirebaseFirestore db, required this.uid})
      : _db = db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('habits');

  Stream<List<Habit>> watchHabits() {
    return _col.snapshots().map((snap) {
      final list = parseDocsSafely(snap.docs, Habit.fromMap, context: 'habits');
      list.sort((a, b) {
        final ad = a.createdAt, bd = b.createdAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
      return list;
    });
  }

  Future<void> add(Habit habit) => _col.add(habit.toMap());

  Future<void> update(Habit habit) =>
      _col.doc(habit.id).set(habit.toMap(), SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Toggle today's completion using an atomic array union/remove.
  Future<void> toggleToday(Habit habit) => toggleDate(habit, DateTime.now());

  /// Toggle completion for any [date] (e.g. backfilling a missed day).
  Future<void> toggleDate(Habit habit, DateTime date) async {
    final id = DateUtilsX.dateId(date);
    final ref = _col.doc(habit.id);
    if (habit.doneOn(date)) {
      await ref.set({
        'completedDates': FieldValue.arrayRemove([id])
      }, SetOptions(merge: true));
    } else {
      await ref.set({
        'completedDates': FieldValue.arrayUnion([id])
      }, SetOptions(merge: true));
    }
  }
}
