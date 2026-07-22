import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../services/notification_service.dart';
import '../../data/habit_repository.dart';
import '../../domain/habit.dart';

final habitRepositoryProvider = Provider<HabitRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return HabitRepository(db: ref.watch(firestoreProvider), uid: uid);
});

final habitsStreamProvider = StreamProvider<List<Habit>>((ref) {
  final repo = ref.watch(habitRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchHabits();
});

/// Best current streak across all habits (for the dashboard/summary).
final bestHabitStreakProvider = Provider<int>((ref) {
  final habits = ref.watch(habitsStreamProvider).valueOrNull ?? const [];
  return habits.fold<int>(0, (m, h) => h.streak > m ? h.streak : m);
});

final habitControllerProvider = Provider<HabitController>((ref) {
  return HabitController(
    ref.watch(habitRepositoryProvider),
    ref.watch(notificationServiceProvider),
  );
});

class HabitController {
  final HabitRepository? _repo;
  final NotificationService _notifications;
  HabitController(this._repo, this._notifications);

  Future<void> add(Habit h) async => _repo?.add(h);
  Future<void> update(Habit h) async => _repo?.update(h);
  Future<void> toggleToday(Habit h) async => _repo?.toggleToday(h);
  Future<void> toggleDate(Habit h, DateTime date) async =>
      _repo?.toggleDate(h, date);

  Future<void> delete(String id) async {
    if (_repo == null) return;
    await _repo.delete(id);
    await _notifications.cancelHabit(id);
  }
}
