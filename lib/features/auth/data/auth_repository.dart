import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/app_user.dart';

/// Handles authentication and the users/{uid} profile document.
class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _db = db,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(AppConstants.usersCollection).doc(uid);

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(displayName.trim());
    await _ensureProfile(cred.user!, displayName: displayName.trim());
    // Send a verification link so the account's email is authenticated.
    await cred.user?.sendEmailVerification();
  }

  /// Whether the signed-in user's email is verified (Google users are always
  /// considered verified).
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  bool get isPasswordUser =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

  Future<void> reloadUser() async => _auth.currentUser?.reload();

  Future<void> resendVerificationEmail() async =>
      _auth.currentUser?.sendEmailVerification();

  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // User cancelled the picker.
      throw FirebaseAuthException(
        code: 'cancelled',
        message: 'Sign-in cancelled',
      );
    }
    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      // No ID token almost always means the OAuth client / SHA-1 fingerprint
      // for this build isn't registered in Firebase, so Google can't mint a
      // Firebase-usable token. Surface a clear, actionable message.
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Google didn\'t return a sign-in token. Make sure this '
            'app\'s SHA-1 fingerprint is added in Firebase Console.',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    await _ensureProfile(cred.user!, displayName: cred.user!.displayName);
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Creates the profile document if it does not yet exist.
  Future<void> _ensureProfile(User user, {String? displayName}) async {
    final ref = _userDoc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final profile = AppUser(
        uid: user.uid,
        displayName: displayName ?? user.displayName,
        email: user.email,
        photoUrl: user.photoURL,
      );
      await ref.set(profile.toMap());
    }
  }

  Stream<AppUser?> watchProfile(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return AppUser.fromMap(uid, data);
    });
  }

  Future<void> updateTargetAttendance(String uid, double target) =>
      _userDoc(uid).set(
        {'targetAttendancePercent': target},
        SetOptions(merge: true),
      );

  Future<void> updateMonthlyBudget(String uid, double budget) =>
      _userDoc(uid).set(
        {'monthlyBudget': budget < 0 ? 0 : budget},
        SetOptions(merge: true),
      );

  Future<void> updateCurrency(String uid, String currency) =>
      _userDoc(uid).set(
        {'currency': currency},
        SetOptions(merge: true),
      );

  Future<void> updateDisplayName(String uid, String name) async {
    await _auth.currentUser?.updateDisplayName(name.trim());
    await _userDoc(uid).set({'displayName': name.trim()}, SetOptions(merge: true));
  }

  /// Full account deletion — required for Play Store data-safety compliance.
  /// Deletes the Firestore profile subtree best-effort, then the auth user.
  /// May throw `requires-recent-login`; caller should prompt re-auth.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _deleteUserData(user.uid);
    await user.delete();
    await _googleSignIn.signOut();
  }

  Future<void> _deleteUserData(String uid) async {
    final subjects =
        await _userDoc(uid).collection(AppConstants.subjectsCollection).get();
    for (final subject in subjects.docs) {
      final sessions =
          await subject.reference.collection(AppConstants.sessionsCollection).get();
      for (final s in sessions.docs) {
        await s.reference.delete();
      }
      final attendance = await subject.reference
          .collection(AppConstants.attendanceCollection)
          .get();
      for (final a in attendance.docs) {
        await a.reference.delete();
      }
      await subject.reference.delete();
    }
    await _userDoc(uid).delete();
  }
}
