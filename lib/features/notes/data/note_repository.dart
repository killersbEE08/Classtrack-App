import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_parsing.dart';
import '../domain/note.dart';

/// CRUD for users/{uid}/notes.
class NoteRepository {
  final FirebaseFirestore _db;
  final String uid;

  NoteRepository({required FirebaseFirestore db, required this.uid})
      : _db = db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('notes');

  Stream<List<Note>> watchNotes() {
    return _col.snapshots().map((snap) {
      final list = parseDocsSafely(snap.docs, Note.fromMap, context: 'notes');
      // Pinned first, then most recently updated.
      list.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final ad = a.updatedAt ?? a.createdAt;
        final bd = b.updatedAt ?? b.createdAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
      return list;
    });
  }

  /// Create and return the new id.
  Future<String> add(Note note) async {
    final ref = await _col.add(note.toMap());
    return ref.id;
  }

  Future<void> update(Note note) =>
      _col.doc(note.id).set(note.toMap(), SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();
}
