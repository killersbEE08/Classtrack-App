import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../../grades/presentation/providers/grade_providers.dart';
import '../../../focus/presentation/providers/study_providers.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../domain/shareable_moment.dart';

/// Builds the list of shareable "moments" from the student's live stats. Only
/// milestones that are actually meaningful (data present, streaks long enough)
/// are surfaced, so a card is always something worth bragging about. A generic
/// "join me" card is always appended so there's never nothing to share.
final momentsProvider = Provider<List<ShareableMoment>>((ref) {
  final overall = ref.watch(overallStatsProvider);
  final week = ref.watch(weeklyAttendanceProvider);
  final streak = ref.watch(bestHabitStreakProvider);
  final gpa = ref.watch(gpaSummaryProvider);
  final study = ref.watch(studyStatsProvider);

  final moments = <ShareableMoment>[];

  // ── Overall attendance ────────────────────────────────────────────────
  if (overall.held > 0) {
    final p = overall.percent.round();
    final (headline, emoji) = p >= 90
        ? ('Attendance royalty', '👑')
        : p >= 75
            ? ('Right on track', '✅')
            : ('On the climb', '📈');
    moments.add(ShareableMoment(
      id: 'attendance',
      emoji: emoji,
      headline: headline,
      value: '$p%',
      valueLabel: 'attendance',
      caption: 'Showing up and staying consistent this semester.',
      shareText: '$p% class attendance this semester $emoji',
      gradient: const [AppColors.primaryLight, AppColors.primary],
    ));
  }

  // ── Perfect week ──────────────────────────────────────────────────────
  if (week.held >= 3 && week.percent >= 100) {
    moments.add(const ShareableMoment(
      id: 'perfect_week',
      emoji: '🌟',
      headline: 'A perfect week',
      value: '100%',
      valueLabel: 'this week',
      caption: 'Every single class attended. Flawless.',
      shareText: '100% attendance this week — didn\'t miss a single class 🌟',
      gradient: [Color(0xFF14B8A6), AppColors.success],
    ));
  }

  // ── Habit streak ──────────────────────────────────────────────────────
  if (streak >= 3) {
    moments.add(ShareableMoment(
      id: 'habit_streak',
      emoji: '🔥',
      headline: 'On fire!',
      value: '$streak',
      valueLabel: streak == 1 ? 'day streak' : 'day streak',
      caption: 'Keeping my daily habit alive, one day at a time.',
      shareText: '$streak-day habit streak and counting 🔥',
      gradient: const [Color(0xFFFB7185), Color(0xFFF97316)],
    ));
  }

  // ── Focus time this week ──────────────────────────────────────────────
  if (study.weekMinutes >= 30) {
    final h = study.weekMinutes ~/ 60;
    final m = study.weekMinutes % 60;
    final value = h > 0 ? (m == 0 ? '${h}h' : '${h}h ${m}m') : '${m}m';
    moments.add(ShareableMoment(
      id: 'focus',
      emoji: '⏱️',
      headline: 'Locked in',
      value: value,
      valueLabel: 'focused this week',
      caption: 'Deep work adds up. Proud of this one.',
      shareText: 'Put in $value of focused study this week ⏱️',
      gradient: const [Color(0xFF0EA5E9), AppColors.primary],
    ));
  }

  // ── Study streak ──────────────────────────────────────────────────────
  if (study.streakDays >= 3) {
    moments.add(ShareableMoment(
      id: 'study_streak',
      emoji: '📚',
      headline: 'Study machine',
      value: '${study.streakDays}',
      valueLabel: 'day study streak',
      caption: 'Showing up for my future self every day.',
      shareText: '${study.streakDays} days of studying in a row 📚',
      gradient: const [Color(0xFF6366F1), Color(0xFF8B7FEC)],
    ));
  }

  // ── GPA ───────────────────────────────────────────────────────────────
  if (gpa.gradedSubjects > 0) {
    final maxLabel = gpa.maxPoints >= 10 ? '10' : '4.0';
    moments.add(ShareableMoment(
      id: 'gpa',
      emoji: '🎓',
      headline: 'Grade goals',
      value: gpa.gpa.toStringAsFixed(2),
      valueLabel: 'GPA / $maxLabel',
      caption: 'The late-night studying is paying off.',
      shareText: 'Current GPA: ${gpa.gpa.toStringAsFixed(2)}/$maxLabel 🎓',
      gradient: const [Color(0xFFF59E0B), Color(0xFFFB7185)],
    ));
  }

  // ── Always-available invite card ──────────────────────────────────────
  moments.add(const ShareableMoment(
    id: 'join_me',
    emoji: '💜',
    headline: 'My study HQ',
    value: 'ClassTrack',
    valueLabel: 'attendance · grades · habits',
    caption: 'Everything for school in one place. Come join me!',
    shareText: 'I run my whole semester on ClassTrack 💜',
    gradient: [AppColors.ink, AppColors.inkSoft],
  ));

  return moments;
});
