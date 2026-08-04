import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../subjects/domain/subject.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../data/session_repository.dart';
import '../../domain/class_session.dart';

final sessionRepositoryProvider = Provider<SessionRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return SessionRepository(db: ref.watch(firestoreProvider), uid: uid);
});

/// Sessions for a single subject.
final sessionsForSubjectProvider =
    StreamProvider.family<List<ClassSession>, String>((ref, subjectId) {
  final repo = ref.watch(sessionRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchForSubject(subjectId);
});

/// A session paired with its subject, for calendar rendering.
class ScheduledClass {
  final Subject subject;
  final ClassSession session;
  const ScheduledClass(this.subject, this.session);
}

/// All sessions across all subjects (aggregated on the client).
final allSessionsProvider = Provider<List<ScheduledClass>>((ref) {
  final subjects = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];
  final result = <ScheduledClass>[];
  for (final s in subjects) {
    final sessions =
        ref.watch(sessionsForSubjectProvider(s.id)).valueOrNull ?? const [];
    // Skip identical (duplicate) sessions so a class never appears twice.
    final seen = <String>{};
    for (final session in sessions) {
      if (!seen.add(session.signature)) continue;
      result.add(ScheduledClass(s, session));
    }
  }
  return result;
});

/// Classes occurring on a given day, sorted by start time. Recurring classes
/// are limited to their subject's course start/end dates (when set).
final classesForDayProvider =
    Provider.family<List<ScheduledClass>, DateTime>((ref, day) {
  final all = ref.watch(allSessionsProvider);
  final d = DateTime(day.year, day.month, day.day);
  final list = all.where((c) {
    if (!c.session.occursOn(day)) return false;
    // Respect the course window for recurring classes.
    if (c.session.recurring) {
      final start = c.subject.startDate;
      final end = c.subject.endDate;
      if (start != null &&
          d.isBefore(DateTime(start.year, start.month, start.day))) {
        return false;
      }
      if (end != null &&
          d.isAfter(DateTime(end.year, end.month, end.day))) {
        return false;
      }
    }
    return true;
  }).toList();
  list.sort((a, b) => DateUtilsX.minutesOfDay(a.session.startTime)
      .compareTo(DateUtilsX.minutesOfDay(b.session.startTime)));
  return list;
});

/// Projected number of classes across a subject's whole term, derived from its
/// recurring timetable sessions and its start/end dates. Returns 0 when the
/// subject has no term set. Powers the "~N classes this term" indicator.
final termScheduledCountProvider =
    Provider.family<int, String>((ref, subjectId) {
  final subject = ref.watch(subjectsByIdProvider)[subjectId];
  if (subject == null || !subject.hasTerm) return 0;
  final sessions =
      ref.watch(sessionsForSubjectProvider(subjectId)).valueOrNull ?? const [];
  var count = 0;
  for (final s in sessions) {
    if (s.recurring && s.dayOfWeek != null) {
      count += DateUtilsX.datesForWeekday(
        start: subject.startDate!,
        end: subject.endDate!,
        weekday0: s.dayOfWeek!,
      ).length;
    }
  }
  return count;
});
