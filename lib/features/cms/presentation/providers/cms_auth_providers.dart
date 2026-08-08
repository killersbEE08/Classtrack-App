import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../domain/cms_role.dart';

/// The signed-in CMS user's role, read from the Firebase Auth custom claim
/// `role` (set server-side by the `setUserRole` Cloud Function). `null` means a
/// normal student / no CMS access.
///
/// Re-evaluated whenever the auth state changes. [forceRefresh] on the token is
/// used so a freshly-granted role is picked up without a full re-login once the
/// UI invalidates this provider.
final cmsRoleProvider = FutureProvider<CmsRole?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final token = await user.getIdTokenResult(true);
  return CmsRole.fromClaim(token.claims?['role']);
});

/// Handles CMS sign-in / sign-out with a loading/error [AsyncValue] state.
class CmsAuthController extends StateNotifier<AsyncValue<void>> {
  final FirebaseAuth _auth;
  CmsAuthController(this._auth) : super(const AsyncData(null));

  Future<bool> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      state = const AsyncData(null);
      return true;
    } on FirebaseAuthException catch (e, st) {
      state = AsyncError(_message(e), st);
      return false;
    } catch (e, st) {
      state = AsyncError('Something went wrong. Try again.', st);
      return false;
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Could not sign in. Please try again.';
    }
  }
}

final cmsAuthControllerProvider =
    StateNotifierProvider<CmsAuthController, AsyncValue<void>>((ref) {
  return CmsAuthController(ref.watch(firebaseAuthProvider));
});
