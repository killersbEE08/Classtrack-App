import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    db: ref.watch(firestoreProvider),
  );
});

/// Streams the current user's profile document (null when signed out).
final userProfileProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});

/// Handles auth mutations with a loading/error [AsyncValue] state.
class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;
  AuthController(this._repo) : super(const AsyncData(null));

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => _repo.signInWithEmail(email, password));

  Future<bool> signUp(String email, String password, String name) =>
      _run(() => _repo.signUpWithEmail(email, password, name));

  Future<bool> signInWithGoogle() => _run(_repo.signInWithGoogle);

  Future<bool> resetPassword(String email) =>
      _run(() => _repo.sendPasswordReset(email));

  Future<bool> deleteAccount() => _run(_repo.deleteAccount);
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
