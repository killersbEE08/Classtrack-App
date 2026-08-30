import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../../features/exams/presentation/providers/exam_providers.dart';
import '../../../../features/import/presentation/providers/import_providers.dart';
import '../../../../features/schedule/presentation/providers/schedule_providers.dart';
import '../../../../features/tasks/presentation/providers/task_providers.dart';
import '../../domain/calendar_push_builder.dart';

/// Two-way sync (Pro) write-back: gathers the user's ClassTrack classes, exams
/// and task deadlines, turns them into Google Calendar event bodies via the
/// pure builders, and pushes them with an idempotent upsert.
class CalendarPushController {
  CalendarPushController(this._ref);

  final Ref _ref;

  /// Pushes everything to the user's Google Calendar and returns how many
  /// events were written/updated. [interactive] false runs silently for the
  /// background auto-push.
  Future<int> push({bool interactive = true}) async {
    final events = await _gatherEvents();
    if (events.isEmpty) return 0;
    final service = _ref.read(googleCalendarServiceProvider);
    return service.pushEvents(events, interactive: interactive);
  }

  Future<List<Map<String, dynamic>>> _gatherEvents() async {
    final tz = await _localTimeZone();
    final now = DateTime.now();
    final events = <Map<String, dynamic>>[];

    // Upcoming exams → timed events.
    for (final exam in _ref.read(upcomingExamsProvider)) {
      events.add(examToEvent(exam, timeZone: tz));
    }

    // Pending task deadlines → all-day / timed events.
    for (final task in _ref.read(pendingTasksProvider)) {
      final ev = taskToEvent(task, timeZone: tz);
      if (ev != null) events.add(ev);
    }

    // Classes → recurring weekly (or one-off) events. allSessionsProvider is
    // already de-duplicated by session signature.
    for (final sc in _ref.read(allSessionsProvider)) {
      final session = sc.session;
      final firstDate = session.recurring
          ? nextWeekdayOnOrAfter(
              sc.subject.startDate ?? now, session.dayOfWeek ?? 0)
          : (session.specificDate ?? now);
      final ev = classSessionToEvent(
        sc.subject,
        session,
        firstDate: firstDate,
        timeZone: tz,
      );
      if (ev != null) events.add(ev);
    }

    return events;
  }

  Future<String> _localTimeZone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      return zone.identifier;
    } catch (_) {
      return 'UTC';
    }
  }
}

final calendarPushControllerProvider = Provider<CalendarPushController>((ref) {
  return CalendarPushController(ref);
});
