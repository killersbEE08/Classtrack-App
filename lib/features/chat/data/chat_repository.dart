import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/chat_session.dart';

/// CRUD for a user's saved AI chat conversations at
/// users/{uid}/chatSessions/{id}.
class ChatRepository {
  final FirebaseFirestore db;
  final String uid;
  ChatRepository({required this.db, required this.uid});

  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection('users').doc(uid).collection('chatSessions');

  /// Generates a new document id without writing anything yet.
  String newId() => _col.doc().id;

  /// Most-recently-updated conversations first.
  Stream<List<ChatSession>> watchSessions() => _col
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => ChatSession.fromMap(d.id, d.data())).toList());

  Future<void> save(ChatSession session) =>
      _col.doc(session.id).set(session.toMap(), SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();
}
