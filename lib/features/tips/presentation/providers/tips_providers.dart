import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../focus/presentation/providers/study_providers.dart';
import '../../../grades/presentation/providers/grade_providers.dart';
import '../../../notes/presentation/providers/note_providers.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../../tasks/domain/task_item.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../domain/discoverable_feature.dart';

/// Records the very first time the app is opened (device-global), so the
/// Tips & Tricks 7-day gate has a stable anchor. No-op after the first call.
/// Call once from `main()` after SharedPreferences is ready.
Future<void> recordFirstLaunchIfNeeded(SharedPreferences prefs) async {
  if (prefs.getInt(AppConstants.prefsFirstLaunchAt) == null) {
    await prefs.setInt(
        AppConstants.prefsFirstLaunchAt, DateTime.now().millisecondsSinceEpoch);
  }
}

/// Whole days since the app was first launched (0 on the first day).
final daysSinceFirstLaunchProvider = Provider<int>((ref) {
  final millis =
      ref.watch(sharedPrefsProvider).getInt(AppConstants.prefsFirstLaunchAt);
  if (millis == null) return 0;
  final first = DateTime.fromMillisecondsSinceEpoch(millis);
  return DateTime.now().difference(first).inDays;
});

/// Tracks the flag-based features the user has tried (the AI features that
/// leave no persistent data). Device-global, like onboarding and the home
/// tour, because these tips teach the app itself.
class FeatureUsageController extends StateNotifier<Set<String>> {
  final SharedPreferences _prefs;
  FeatureUsageController(this._prefs)
      : super(
            (_prefs.getStringList(AppConstants.prefsFeaturesUsed) ?? const [])
                .toSet());

  /// Marks [featureId] as used. Idempotent and safe to call from hot paths.
  Future<void> markUsed(String featureId) async {
    if (state.contains(featureId)) return;
    final next = {...state, featureId};
    state = next;
    await _prefs.setStringList(
        AppConstants.prefsFeaturesUsed, next.toList());
  }
}

final featureUsageProvider =
    StateNotifierProvider<FeatureUsageController, Set<String>>((ref) {
  return FeatureUsageController(ref.watch(sharedPrefsProvider));
});

/// The full Tips & Tricks checklist, with each feature's [done] state resolved
/// from the user's own data (where it leaves a trace) or a usage flag (for the
/// AI features). Kept in a stable, curated order so progress feels consistent.
final discoveredFeaturesProvider = Provider<List<DiscoverableFeature>>((ref) {
  final used = ref.watch(featureUsageProvider);

  final subjects = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];
  final tasks = ref.watch(tasksStreamProvider).valueOrNull ?? const [];
  final notes = ref.watch(notesStreamProvider).valueOrNull ?? const [];
  final sessions =
      ref.watch(studySessionsStreamProvider).valueOrNull ?? const [];
  final grades = ref.watch(gradesStreamProvider).valueOrNull ?? const [];
  final expenses = ref.watch(expensesStreamProvider).valueOrNull ?? const [];

  // Inferred-from-data signals.
  final trackedAttendance = subjects.any((s) => s.held > 0);
  final importedCalendar = tasks.any((t) => (t.sourceId ?? '').isNotEmpty);
  final savedVideo = tasks.any((t) => t.type == TaskType.video);
  final madeFlashcards = notes.any((n) => n.hasFlashcards);
  final usedFocusTimer = sessions.isNotEmpty;
  final loggedGrades = grades.isNotEmpty;
  final trackedExpenses = expenses.isNotEmpty;

  return [
    DiscoverableFeature(
      id: FeatureId.attendance,
      title: 'Track attendance',
      subtitle: 'Mark classes present or absent and watch your live %.',
      icon: Icons.pie_chart_rounded,
      color: AppColors.primary,
      done: trackedAttendance,
    ),
    DiscoverableFeature(
      id: FeatureId.googleCalendar,
      title: 'Google Calendar import',
      subtitle: 'Bring your existing schedule in with one tap.',
      icon: Icons.event_available_rounded,
      color: AppColors.info,
      done: importedCalendar,
    ),
    DiscoverableFeature(
      id: FeatureId.dailySummary,
      title: 'AI daily summary',
      subtitle: 'A friendly morning briefing of your day, written by AI.',
      icon: Icons.today_rounded,
      color: AppColors.primaryLight,
      done: used.contains(FeatureId.dailySummary),
    ),
    DiscoverableFeature(
      id: FeatureId.aiAssistant,
      title: 'AI assistant',
      subtitle: 'Ask things like “When am I free tomorrow?”',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.accent,
      done: used.contains(FeatureId.aiAssistant),
    ),
    DiscoverableFeature(
      id: FeatureId.shareVideo,
      title: 'Share YouTube videos',
      subtitle: 'Share any video to ClassTrack to make a study task.',
      icon: Icons.play_circle_fill_rounded,
      color: AppColors.coral,
      done: savedVideo,
    ),
    DiscoverableFeature(
      id: FeatureId.flashcards,
      title: 'Flashcards',
      subtitle: 'Turn your notes into a deck you can study.',
      icon: Icons.style_rounded,
      color: AppColors.info,
      done: madeFlashcards,
    ),
    DiscoverableFeature(
      id: FeatureId.focusTimer,
      title: 'Focus timer',
      subtitle: 'Run study sessions and build a daily streak.',
      icon: Icons.timer_rounded,
      color: AppColors.coral,
      done: usedFocusTimer,
    ),
    DiscoverableFeature(
      id: FeatureId.photoImport,
      title: 'Photo timetable import',
      subtitle: 'Snap or upload a timetable and let AI build it.',
      icon: Icons.document_scanner_rounded,
      color: AppColors.primary,
      done: used.contains(FeatureId.photoImport),
    ),
    DiscoverableFeature(
      id: FeatureId.grades,
      title: 'Grades & GPA',
      subtitle: 'Log marks and track your GPA over time.',
      icon: Icons.school_rounded,
      color: AppColors.primaryLight,
      done: loggedGrades,
    ),
    DiscoverableFeature(
      id: FeatureId.expenses,
      title: 'Expense tracking',
      subtitle: 'Log spending and stay on top of your budget.',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.success,
      done: trackedExpenses,
    ),
  ];
});

/// Aggregate progress across the Tips & Tricks checklist.
typedef FeatureProgress = ({int done, int total, double percent});

final featureProgressProvider = Provider<FeatureProgress>((ref) {
  final features = ref.watch(discoveredFeaturesProvider);
  final done = features.where((f) => f.done).length;
  final total = features.length;
  final percent = total == 0 ? 0.0 : done * 100.0 / total;
  return (done: done, total: total, percent: percent);
});

/// Whether the once-only "you're using X% of ClassTrack" prompt has been shown.
class TipsPromptController extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  TipsPromptController(this._prefs)
      : super(_prefs.getBool(AppConstants.prefsTipsPromptShown) ?? false);

  Future<void> markShown() async {
    if (state) return;
    state = true;
    await _prefs.setBool(AppConstants.prefsTipsPromptShown, true);
  }
}

final tipsPromptShownProvider =
    StateNotifierProvider<TipsPromptController, bool>((ref) {
  return TipsPromptController(ref.watch(sharedPrefsProvider));
});

/// True when the app should auto-open the Tips & Tricks page: at least 7 days
/// of use, the prompt hasn't been shown yet, and there's still something left
/// to discover (progress < 100%).
final shouldShowTipsPromptProvider = Provider<bool>((ref) {
  if (ref.watch(tipsPromptShownProvider)) return false;
  if (ref.watch(daysSinceFirstLaunchProvider) < 7) return false;
  return ref.watch(featureProgressProvider).percent < 100;
});
