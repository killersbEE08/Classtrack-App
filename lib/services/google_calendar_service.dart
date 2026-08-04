import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';

/// Thrown when the user dismisses the Google account/consent picker.
class GoogleCalendarCancelled implements Exception {
  const GoogleCalendarCancelled();
  @override
  String toString() => 'Google Calendar import cancelled';
}

/// Thrown when the Calendar API request itself fails (permission, network, …).
class GoogleCalendarException implements Exception {
  final String message;
  const GoogleCalendarException(this.message);
  @override
  String toString() => message;
}

/// Signs the user in with the read-only Calendar scope and fetches their
/// upcoming events from the Google Calendar API v3.
///
/// Uses its own [GoogleSignIn] instance (separate from the auth sign-in) so it
/// can request the extra calendar scope without changing the app's login
/// scopes. Requests instances (`singleEvents=true`) over a short upcoming
/// window so the pure mapper can reconstruct the weekly timetable.
///
/// NOTE (setup): the `calendar.readonly` scope must be enabled on the OAuth
/// consent screen for this project's client, and the Google Calendar API must
/// be enabled in the Google Cloud console, for the consent prompt to succeed on
/// real devices.
class GoogleCalendarService {
  final GoogleSignIn _signIn;
  final http.Client _client;

  GoogleCalendarService({GoogleSignIn? signIn, http.Client? client})
      : _signIn = signIn ??
            GoogleSignIn(
              serverClientId: AppConstants.googleServerClientId,
              scopes: const <String>[AppConstants.googleCalendarScope],
            ),
        _client = client ?? http.Client();

  /// Signs in (if needed), then returns the raw event JSON objects for the
  /// user's primary calendar across [windowDays] ahead (default 4 weeks).
  ///
  /// Throws [GoogleCalendarCancelled] if the user backs out, or
  /// [GoogleCalendarException] if the API call fails.
  Future<List<Map<String, dynamic>>> fetchUpcomingEvents({
    int windowDays = 28,
  }) async {
    GoogleSignInAccount? account = await _signIn.signInSilently();
    account ??= await _signIn.signIn();
    if (account == null) throw const GoogleCalendarCancelled();

    // Make sure the calendar scope was actually granted (incremental consent).
    final granted = await _signIn.requestScopes(
      const <String>[AppConstants.googleCalendarScope],
    );
    if (!granted) throw const GoogleCalendarCancelled();

    final headers = await account.authHeaders;

    final now = DateTime.now().toUtc();
    final timeMin = now.subtract(const Duration(days: 1)).toIso8601String();
    final timeMax = now.add(Duration(days: windowDays)).toIso8601String();

    final uri = Uri.https(
      'www.googleapis.com',
      '/calendar/v3/calendars/primary/events',
      <String, String>{
        'singleEvents': 'true',
        'orderBy': 'startTime',
        'timeMin': timeMin,
        'timeMax': timeMax,
        'maxResults': '250',
      },
    );

    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw GoogleCalendarException(
        'Calendar request failed (${res.statusCode}). '
        'Please try again or check calendar access.',
      );
    }

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw const GoogleCalendarException('Unexpected response from Calendar.');
    }
    final items = body['items'];
    if (items is! List) return const <Map<String, dynamic>>[];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  void dispose() => _client.close();
}
