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

  /// Signs in (if needed), then returns the raw event JSON objects from ALL of
  /// the user's calendars (not just `primary`). The window spans [backDays] in
  /// the past through [windowDays] ahead.
  ///
  /// Why all calendars: many students keep their timetable in a *secondary*
  /// calendar (a college/subscribed calendar, or a calendar on a non-default
  /// account), so a primary-only fetch returned nothing on those phones/
  /// accounts ("no upcoming events found") while working fine on others. We
  /// read the primary calendar first (its failure surfaces as a real error so
  /// a genuine permission problem isn't hidden), then merge in every other
  /// readable calendar best-effort, de-duplicating by event id.
  ///
  /// Looking a few weeks back matters for re-imports: an event earlier today
  /// would fall outside a "now onward" window.
  ///
  /// Throws [GoogleCalendarCancelled] if the user backs out, or
  /// [GoogleCalendarException] if the primary calendar call fails.
  Future<List<Map<String, dynamic>>> fetchUpcomingEvents({
    int windowDays = 60,
    int backDays = 30,
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
    final timeMin = now.subtract(Duration(days: backDays)).toIso8601String();
    final timeMax = now.add(Duration(days: windowDays)).toIso8601String();

    // De-dup by event id across calendars (the same event can appear in more
    // than one calendar). Events without an id are always kept.
    final byId = <String, Map<String, dynamic>>{};
    var fallbackKey = 0;
    void addAll(List<Map<String, dynamic>> events) {
      for (final e in events) {
        final id = e['id'];
        final key =
            (id is String && id.isNotEmpty) ? id : '__${fallbackKey++}';
        byId.putIfAbsent(key, () => e);
      }
    }

    // Primary calendar is authoritative: a hard failure here (e.g. permission)
    // surfaces as an error rather than a silent empty import.
    addAll(await _eventsForCalendar('primary', headers, timeMin, timeMax,
        throwOnError: true));

    // Merge in the user's other calendars. Best-effort: skip any we can't read.
    try {
      for (final calId in await _otherCalendarIds(headers)) {
        addAll(await _eventsForCalendar(calId, headers, timeMin, timeMax,
            throwOnError: false));
      }
    } catch (_) {
      // Secondary calendars are a bonus — never let them break the import.
    }

    return byId.values.toList();
  }

  /// Fetches the timed/all-day events of a single calendar in the window.
  /// Throws only when [throwOnError] is true (used for the primary calendar).
  Future<List<Map<String, dynamic>>> _eventsForCalendar(
    String calendarId,
    Map<String, String> headers,
    String timeMin,
    String timeMax, {
    required bool throwOnError,
  }) async {
    final uri = Uri.https(
      'www.googleapis.com',
      '/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events',
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
      if (throwOnError) {
        throw GoogleCalendarException(
          'Calendar request failed (${res.statusCode}). '
          'Please try again or check calendar access.',
        );
      }
      return const <Map<String, dynamic>>[];
    }

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      if (throwOnError) {
        throw const GoogleCalendarException(
            'Unexpected response from Calendar.');
      }
      return const <Map<String, dynamic>>[];
    }
    final items = body['items'];
    if (items is! List) return const <Map<String, dynamic>>[];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  /// Ids of the user's readable calendars EXCEPT the primary one (already
  /// fetched) and the noisy auto-generated holiday/birthday calendars.
  /// Best-effort: returns an empty list on any failure.
  Future<List<String>> _otherCalendarIds(Map<String, String> headers) async {
    try {
      final uri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/users/me/calendarList',
        <String, String>{'maxResults': '250', 'minAccessRole': 'reader'},
      );
      final res = await _client.get(uri, headers: headers);
      if (res.statusCode != 200) return const <String>[];
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) return const <String>[];
      final items = body['items'];
      if (items is! List) return const <String>[];

      final ids = <String>[];
      for (final c in items.whereType<Map<String, dynamic>>()) {
        if (c['primary'] == true) continue; // already fetched via 'primary'
        final id = c['id'];
        if (id is! String || id.isEmpty) continue;
        // Skip auto-generated calendars that would flood Tasks with noise.
        if (id.contains('#holiday@') || id.contains('#contacts@')) continue;
        ids.add(id);
      }
      return ids;
    } catch (_) {
      return const <String>[];
    }
  }

  /// Fetches the user's Google **Tasks** (to-dos) across all of their task
  /// lists.
  ///
  /// Best-effort by design: it requests the Tasks scope incrementally, so a
  /// user who only granted calendar access (or a project where the Google
  /// Tasks API / scope isn't enabled) simply gets an empty list — event import
  /// keeps working regardless. Only incomplete, non-deleted tasks are returned.
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    try {
      GoogleSignInAccount? account = await _signIn.signInSilently();
      account ??= await _signIn.signIn();
      if (account == null) return const <Map<String, dynamic>>[];

      final granted = await _signIn
          .requestScopes(const <String>[AppConstants.googleTasksScope]);
      if (!granted) return const <Map<String, dynamic>>[];

      final headers = await account.authHeaders;

      // 1) Enumerate the user's task lists.
      final listsUri = Uri.https(
        'tasks.googleapis.com',
        '/tasks/v1/users/@me/lists',
        <String, String>{'maxResults': '100'},
      );
      final listsRes = await _client.get(listsUri, headers: headers);
      if (listsRes.statusCode != 200) return const <Map<String, dynamic>>[];
      final listsBody = jsonDecode(listsRes.body);
      if (listsBody is! Map<String, dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      final lists = listsBody['items'];
      if (lists is! List) return const <Map<String, dynamic>>[];

      // 2) Pull the incomplete tasks from each list.
      final out = <Map<String, dynamic>>[];
      for (final l in lists.whereType<Map<String, dynamic>>()) {
        final listId = l['id'];
        if (listId is! String || listId.isEmpty) continue;
        final tasksUri = Uri.https(
          'tasks.googleapis.com',
          '/tasks/v1/lists/$listId/tasks',
          <String, String>{
            'showCompleted': 'false',
            'showHidden': 'false',
            'maxResults': '100',
          },
        );
        final tRes = await _client.get(tasksUri, headers: headers);
        if (tRes.statusCode != 200) continue; // skip a list we can't read
        final tBody = jsonDecode(tRes.body);
        if (tBody is Map<String, dynamic>) {
          final tItems = tBody['items'];
          if (tItems is List) {
            out.addAll(tItems.whereType<Map<String, dynamic>>());
          }
        }
      }
      return out;
    } catch (_) {
      // Tasks import is a bonus path — never let it break the overall import.
      return const <Map<String, dynamic>>[];
    }
  }

  void dispose() => _client.close();
}
