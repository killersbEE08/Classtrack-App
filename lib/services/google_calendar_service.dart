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

/// The [timeMin, timeMax] RFC3339/UTC bounds for a calendar query, computed
/// from [now] (defaults to the current instant). Extracted as a pure function
/// so the "never look back more than a week" rule can be unit-tested without
/// any network or OAuth.
///
/// [backDays] caps how far into the past the import reaches; [forwardDays] how
/// far ahead. Both default to the app-wide Google-import window.
class CalendarWindow {
  final String timeMin;
  final String timeMax;
  const CalendarWindow(this.timeMin, this.timeMax);
}

CalendarWindow calendarWindow({
  DateTime? now,
  int backDays = AppConstants.googleImportBackDays,
  int forwardDays = AppConstants.googleImportForwardDays,
}) {
  final base = (now ?? DateTime.now()).toUtc();
  return CalendarWindow(
    base.subtract(Duration(days: backDays)).toIso8601String(),
    base.add(Duration(days: forwardDays)).toIso8601String(),
  );
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
  ///
  /// When [interactive] is false the method runs SILENTLY: it only reuses an
  /// existing signed-in session ([signInSilently]) and already-granted scopes,
  /// and never pops the account/consent picker — used by the daily background
  /// auto-sync so it can never interrupt the user with a dialog.
  Future<List<Map<String, dynamic>>> fetchUpcomingEvents({
    int windowDays = AppConstants.googleImportForwardDays,
    int backDays = AppConstants.googleImportBackDays,
    bool interactive = true,
  }) async {
    GoogleSignInAccount? account = await _signIn.signInSilently();
    if (interactive) {
      account ??= await _signIn.signIn();
    }
    if (account == null) throw const GoogleCalendarCancelled();

    // Make sure the calendar scope was actually granted (incremental consent).
    // In silent mode this returns true without UI when the scope was already
    // granted (the auto-sync only runs for accounts that connected before), and
    // any denial simply aborts the silent sync instead of prompting.
    final granted = await _signIn.requestScopes(
      const <String>[AppConstants.googleCalendarScope],
    );
    if (!granted) throw const GoogleCalendarCancelled();

    final headers = await account.authHeaders;

    final window = calendarWindow(backDays: backDays, forwardDays: windowDays);
    final timeMin = window.timeMin;
    final timeMax = window.timeMax;

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
  Future<List<Map<String, dynamic>>> fetchTasks({bool interactive = true}) async {
    try {
      GoogleSignInAccount? account = await _signIn.signInSilently();
      if (interactive) {
        account ??= await _signIn.signIn();
      }
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

  /// Writes ClassTrack events INTO the user's primary Google Calendar
  /// (two-way sync, Pro). Each event map (built by the pure builders in
  /// `calendar_push_builder.dart`) carries a deterministic `id`, so this is an
  /// idempotent UPSERT: it tries `events.insert`, and on a `409` "already
  /// exists" it falls back to `events.update` on that id. Re-pushing the same
  /// items therefore updates them in place instead of creating duplicates.
  ///
  /// Requests the calendar WRITE scope incrementally. When [interactive] is
  /// false it runs silently (existing session + already-granted scope only) for
  /// the background auto-push; a missing session/scope simply yields 0 writes
  /// rather than a prompt. Returns the number of events successfully upserted.
  ///
  /// Throws [GoogleCalendarCancelled] if an interactive user backs out of the
  /// sign-in/consent flow.
  Future<int> pushEvents(
    List<Map<String, dynamic>> events, {
    bool interactive = true,
  }) async {
    if (events.isEmpty) return 0;

    GoogleSignInAccount? account = await _signIn.signInSilently();
    if (interactive) {
      account ??= await _signIn.signIn();
    }
    if (account == null) {
      if (interactive) throw const GoogleCalendarCancelled();
      return 0;
    }

    final granted = await _signIn.requestScopes(
      const <String>[AppConstants.googleCalendarWriteScope],
    );
    if (!granted) {
      if (interactive) throw const GoogleCalendarCancelled();
      return 0;
    }

    final headers = <String, String>{
      ...await account.authHeaders,
      'Content-Type': 'application/json',
    };

    var written = 0;
    for (final event in events) {
      if (await _upsertEvent(event, headers)) written++;
    }
    return written;
  }

  /// Inserts [event] on the primary calendar; on `409` (id already exists)
  /// updates the existing event instead. Best-effort per event: a single
  /// failure never aborts the rest of the batch.
  Future<bool> _upsertEvent(
    Map<String, dynamic> event,
    Map<String, String> headers,
  ) async {
    final id = event['id'] as String?;
    final body = jsonEncode(event);
    try {
      final insertUri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/primary/events',
      );
      final res = await _client.post(insertUri, headers: headers, body: body);
      if (res.statusCode == 200 || res.statusCode == 201) return true;

      // 409 = an event with this deterministic id already exists → update it.
      if (res.statusCode == 409 && id != null) {
        final updateUri = Uri.https(
          'www.googleapis.com',
          '/calendar/v3/calendars/primary/events/${Uri.encodeComponent(id)}',
        );
        final up = await _client.put(updateUri, headers: headers, body: body);
        return up.statusCode == 200;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _client.close();
}
