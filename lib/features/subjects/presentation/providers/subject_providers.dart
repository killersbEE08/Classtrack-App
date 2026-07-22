import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../data/subject_repository.dart';
import '../../domain/subject.dart';

/// Repository bound to the current user. Null when signed out.
final subjectRepositoryProvider = Provider<SubjectRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return SubjectRepository(db: ref.watch(firestoreProvider), uid: uid);
});

/// Live list of the user's subjects.
final subjectsStreamProvider = StreamProvider<List<Subject>>((ref) {
  final repo = ref.watch(subjectRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchSubjects();
});

/// Live single subject by id.
final subjectProvider =
    StreamProvider.family<Subject?, String>((ref, id) {
  final repo = ref.watch(subjectRepositoryProvider);
  if (repo == null) return Stream.value(null);
  return repo.watchSubject(id);
});

/// Quick lookup map id -> Subject (derived from the list stream).
final subjectsByIdProvider = Provider<Map<String, Subject>>((ref) {
  final list = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];
  return {for (final s in list) s.id: s};
});
