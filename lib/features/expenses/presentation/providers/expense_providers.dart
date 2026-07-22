import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/expense_repository.dart';
import '../../domain/expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return ExpenseRepository(db: ref.watch(firestoreProvider), uid: uid);
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchExpenses();
});

/// Expenses in the current calendar month.
final thisMonthExpensesProvider = Provider<List<Expense>>((ref) {
  final all = ref.watch(expensesStreamProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  return all
      .where((e) => e.date.year == now.year && e.date.month == now.month)
      .toList();
});

/// Total spent this month.
final monthlyTotalProvider = Provider<double>((ref) {
  final month = ref.watch(thisMonthExpensesProvider);
  return month.fold<double>(0, (a, e) => a + e.amount);
});

/// This month's spend grouped by category (descending by amount).
final categoryBreakdownProvider =
    Provider<List<MapEntry<ExpenseCategory, double>>>((ref) {
  final month = ref.watch(thisMonthExpensesProvider);
  final map = <ExpenseCategory, double>{};
  for (final e in month) {
    map[e.category] = (map[e.category] ?? 0) + e.amount;
  }
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
});

final expenseControllerProvider = Provider<ExpenseController>((ref) {
  return ExpenseController(ref.watch(expenseRepositoryProvider));
});

class ExpenseController {
  final ExpenseRepository? _repo;
  ExpenseController(this._repo);

  Future<void> add(Expense e) async => _repo?.add(e);
  Future<void> update(Expense e) async => _repo?.update(e);
  Future<void> delete(String id) async => _repo?.delete(id);
}



/// Currency symbol — stored per-user in the Firestore profile so it survives
/// logout/login and syncs across devices.
final currencySymbolProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).valueOrNull?.currency ?? '₹';
});

/// Monthly budget — per-user in the profile (0 = not set).
final monthlyBudgetProvider = Provider<double>((ref) {
  return ref.watch(userProfileProvider).valueOrNull?.monthlyBudget ?? 0;
});

final expenseSettingsProvider = Provider<ExpenseSettings>((ref) {
  return ExpenseSettings(ref);
});

class ExpenseSettings {
  final Ref _ref;
  ExpenseSettings(this._ref);

  Future<void> setBudget(double value) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(authRepositoryProvider).updateMonthlyBudget(uid, value);
  }

  Future<void> setCurrency(String symbol) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(authRepositoryProvider).updateCurrency(uid, symbol);
  }
}
