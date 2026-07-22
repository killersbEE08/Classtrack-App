import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/study_repository.dart';
import '../../domain/study_session.dart';

final studyRepositoryProvider = Provider<StudyRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return StudyRepository(db: ref.watch(firestoreProvider), uid: uid);
});

final studySessionsStreamProvider = StreamProvider<List<StudySession>>((ref) {
  final repo = ref.watch(studyRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchSessions();
});

class StudyStats {
  final int todayMinutes;
  final int weekMinutes;
  final int todaySessions;
  final int streakDays;

  const StudyStats({
    required this.todayMinutes,
    required this.weekMinutes,
    required this.todaySessions,
    required this.streakDays,
  });

  static const empty =
      StudyStats(todayMinutes: 0, weekMinutes: 0, todaySessions: 0, streakDays: 0);
}

final studyStatsProvider = Provider<StudyStats>((ref) {
  final sessions =
      ref.watch(studySessionsStreamProvider).valueOrNull ?? const [];
  if (sessions.isEmpty) return StudyStats.empty;

  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  int today = 0, week = 0, todayCount = 0;
  final daysWithStudy = <String>{};

  for (final s in sessions) {
    if (DateUtilsX.isSameDay(s.startedAt, now)) {
      today += s.minutes;
      todayCount++;
    }
    if (s.startedAt.isAfter(weekAgo)) week += s.minutes;
    daysWithStudy.add(DateUtilsX.dateId(s.startedAt));
  }

  // Consecutive-day streak ending today (or yesterday).
  int streak = 0;
  var cursor = DateTime(now.year, now.month, now.day);
  if (!daysWithStudy.contains(DateUtilsX.dateId(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (daysWithStudy.contains(DateUtilsX.dateId(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return StudyStats(
    todayMinutes: today,
    weekMinutes: week,
    todaySessions: todayCount,
    streakDays: streak,
  );
});

final studyControllerProvider = Provider<StudyController>((ref) {
  return StudyController(ref.watch(studyRepositoryProvider));
});

class StudyController {
  final StudyRepository? _repo;
  StudyController(this._repo);

  Future<void> logSession({
    required int minutes,
    String? subjectId,
    DateTime? startedAt,
  }) async {
    if (minutes <= 0) return;
    await _repo?.add(StudySession(
      id: 'new',
      subjectId: subjectId,
      startedAt: startedAt ?? DateTime.now(),
      minutes: minutes,
    ));
  }

  Future<void> delete(String id) async => _repo?.delete(id);
}
