import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../data/note_attachment_service.dart';
import '../../data/note_repository.dart';
import '../../domain/note.dart';

final noteRepositoryProvider = Provider<NoteRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return NoteRepository(db: ref.watch(firestoreProvider), uid: uid);
});

/// Uploads/deletes note file attachments (images & PDFs) in Firebase Storage.
final noteAttachmentServiceProvider =
    Provider<NoteAttachmentService?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return NoteAttachmentService(
    storage: ref.watch(firebaseStorageProvider),
    uid: uid,
  );
});

final notesStreamProvider = StreamProvider<List<Note>>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchNotes();
});

final noteControllerProvider = Provider<NoteController>((ref) {
  return NoteController(
    ref.watch(noteRepositoryProvider),
    ref.watch(noteAttachmentServiceProvider),
  );
});

class NoteController {
  final NoteRepository? _repo;
  final NoteAttachmentService? _attachments;
  NoteController(this._repo, this._attachments);

  Future<String?> add(Note n) async => _repo?.add(n);
  Future<void> update(Note n) async => _repo?.update(n);
  Future<void> delete(String id) async => _repo?.delete(id);

  /// Deletes a note along with its Storage attachments (best-effort cleanup so
  /// removing a note doesn't orphan uploaded files).
  Future<void> deleteNote(Note n) async {
    if (n.attachments.isNotEmpty) {
      await _attachments?.deleteAll(n.attachments);
    }
    await _repo?.delete(n.id);
  }

  Future<void> togglePin(Note n) async =>
      _repo?.update(n.copyWith(pinned: !n.pinned, updatedAt: DateTime.now()));
}
