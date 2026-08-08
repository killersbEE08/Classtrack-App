import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/resource_repository.dart';
import '../../domain/resource.dart';
import '../../domain/resource_type.dart';

/// Read-only repository over the unified `resources` collection.
final resourceRepositoryProvider = Provider<ResourceRepository>((ref) {
  return ResourceRepository(db: ref.watch(firestoreProvider));
});

/// All student-visible resources (priority-ordered). Base stream that the
/// Opportunities & Discounts surfaces derive from.
final visibleResourcesProvider = StreamProvider<List<Resource>>((ref) {
  return ref.watch(resourceRepositoryProvider).watchVisible();
});

/// A single resource by id (for detail pages / deep links).
final resourceByIdProvider =
    StreamProvider.family<Resource?, String>((ref, id) {
  return ref.watch(resourceRepositoryProvider).watchById(id);
});

/// Active-feed opportunities (excludes discounts), country-filtered to the
/// signed-in user's profile country.
final opportunitiesFeedProvider = Provider<List<Resource>>((ref) {
  final all = ref.watch(visibleResourcesProvider).valueOrNull ?? const [];
  final country = ref.watch(userProfileProvider).valueOrNull?.country;
  return ResourceQueries.feed(all, country: country)
      .where((r) => !r.type.isDiscount)
      .toList();
});

/// Active-feed discounts, country-filtered.
final discountsFeedProvider = Provider<List<Resource>>((ref) {
  final all = ref.watch(visibleResourcesProvider).valueOrNull ?? const [];
  final country = ref.watch(userProfileProvider).valueOrNull?.country;
  return ResourceQueries.feed(all,
      type: ResourceType.discount, country: country);
});

/// Feed filtered to a single [ResourceType], country-aware.
final resourcesByTypeProvider =
    Provider.family<List<Resource>, ResourceType>((ref, type) {
  final all = ref.watch(visibleResourcesProvider).valueOrNull ?? const [];
  final country = ref.watch(userProfileProvider).valueOrNull?.country;
  return ResourceQueries.feed(all, type: type, country: country);
});

// ── Saved / hidden opportunities ────────────────────────────────────────────

/// Per-user saved-resources repository (null when signed out).
final savedResourceRepositoryProvider =
    Provider<SavedResourceRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return SavedResourceRepository(db: ref.watch(firestoreProvider), uid: uid);
});

/// Set of saved resource ids (empty when signed out).
final savedResourceIdsProvider = StreamProvider<Set<String>>((ref) {
  final repo = ref.watch(savedResourceRepositoryProvider);
  if (repo == null) return Stream.value(const <String>{});
  return repo.watchSavedIds();
});

/// Ids the user hid ("not interested"), filtered out of the feeds by the UI.
final hiddenResourceIdsProvider = StreamProvider<Set<String>>((ref) {
  final repo = ref.watch(savedResourceRepositoryProvider);
  if (repo == null) return Stream.value(const <String>{});
  return repo.watchHiddenIds();
});

/// The user's saved resources, hydrated to live [Resource]s. Saved items remain
/// available even after their status changes (PRD §15).
final savedResourcesProvider = FutureProvider<List<Resource>>((ref) async {
  final ids = ref.watch(savedResourceIdsProvider).valueOrNull ?? const <String>{};
  if (ids.isEmpty) return const [];
  return ref.watch(resourceRepositoryProvider).fetchByIds(ids);
});

/// Save/unsave/hide actions for opportunities.
final savedResourceControllerProvider =
    Provider<SavedResourceController>((ref) {
  return SavedResourceController(ref.watch(savedResourceRepositoryProvider));
});

class SavedResourceController {
  final SavedResourceRepository? _repo;
  SavedResourceController(this._repo);

  bool get isReady => _repo != null;

  Future<void> save(Resource r) async => _repo?.save(r);
  Future<void> unsave(String id) async => _repo?.unsave(id);
  Future<void> hide(String id) async => _repo?.setHidden(id, true);
  Future<void> unhide(String id) async => _repo?.setHidden(id, false);

  /// Toggles saved state given the current saved-id set.
  Future<void> toggle(Resource r, Set<String> currentSaved) async {
    if (currentSaved.contains(r.id)) {
      await unsave(r.id);
    } else {
      await save(r);
    }
  }
}
