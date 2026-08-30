import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../data/media_repository.dart';
import '../../domain/media_asset.dart';

final mediaRepositoryProvider = Provider<MediaRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return MediaRepository(
    db: ref.watch(firestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
    uid: uid,
  );
});

final cmsMediaProvider = StreamProvider<List<MediaAsset>>((ref) {
  final repo = ref.watch(mediaRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAll();
});
