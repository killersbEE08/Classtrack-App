import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

/// Human-friendly text for auth errors.
String friendlyAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Please choose a stronger password — at least 8 characters '
            'with letters and numbers.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      case 'account-exists-with-different-credential':
        return 'You already signed up with a different method for this email.';
      case 'google-no-token':
        return 'Couldn\'t complete Google sign-in on this build. Please try '
            'again in a few minutes, or use email sign-in.';
      case 'cancelled':
        return 'Sign-in cancelled.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
  // Google Sign-In / native channel failures surface as PlatformException.
  if (error is PlatformException) {
    switch (error.code) {
      // ApiException 10 (DEVELOPER_ERROR): the app's SHA-1/SHA-256 fingerprint
      // is not registered for this Firebase project, or google-services.json
      // is stale. This is a configuration issue, not a user mistake.
      case '10':
      case 'sign_in_failed':
        return 'Google sign-in isn\'t configured for this build yet. '
            'Add your app\'s SHA-1 fingerprint in Firebase and try again.';
      case '7':
      case 'network_error':
        return 'Network error during Google sign-in. Check your connection.';
      case '12501':
      case 'canceled':
      case 'cancelled':
        return 'Sign-in cancelled.';
      case '12500':
        return 'Google sign-in failed. Update Google Play services and retry.';
      default:
        return error.message?.isNotEmpty == true
            ? 'Google sign-in failed: ${error.message}'
            : 'Google sign-in failed. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
