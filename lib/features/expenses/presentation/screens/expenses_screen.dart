import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../insights/domain/insight_math.dart';
import '../../../../shared/widgets/states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/expense.dart';
import '../providers/expense_providers.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  late DateTime _month;
  ExpenseCategory? _filter; // null = all categories

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  int get _daysForAverage {
    final now = DateTime.now();
    if (_isCurrentMonth) return now.day;
    return DateTime(_month.year, _month.month + 1, 0).day; // days in month
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _filter = null;
    });
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (DateUtilsX.isSameDay(d, now)) return 'Today';
    if (DateUtilsX.isSameDay(d, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateUtilsX.prettyDate(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final currency = ref.watch(currencySymbolProvider);
    final budget = ref.watch(monthlyBudgetProvider);
    final all = expensesAsync.valueOrNull ?? const <Expense>[];
    final monthExpenses = all
        .where((e) =>
            e.date.year == _month.year && e.date.month == _month.month)
        .toList();
    final total = monthExpenses.fold<double>(0, (a, e) => a + e.amount);

    final breakdown = <ExpenseCategory, double>{};
    for (final e in monthExpenses) {
      breakdown[e.category] = (breakdown[e.category] ?? 0) + e.amount;
    }
    final breakdownList = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Projected month-end spend (current month only): extrapolate today's rate.
    final projected = _isCurrentMonth
        ? projectedMonthlySpend(spentSoFar: total, now: DateTime.now())
        : total;

    final filtered = _filter == null
        ? monthExpenses
        : monthExpenses.where((e) => e.category == _filter).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _currencyButton(context, currency),
                const SizedBox(width: 8),
                _AddButton(onTap: () => _openEditor(context)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Expenses',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _monthSwitcher(theme),
            const SizedBox(height: 16),
            _totalCard(context, theme, total, budget, currency, projected)
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.06, curve: Curves.easeOut),
            const SizedBox(height: 14),
            _statsRow(theme, monthExpenses.length, total, currency,
                breakdownList.isEmpty ? null : breakdownList.first.key),
            const SizedBox(height: 20),
            if (breakdownList.isNotEmpty) ...[
              _breakdownCard(context, theme, breakdownList, total, currency),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Text('Transactions', style: theme.textTheme.titleLarge),
                const Spacer(),
                if (monthExpenses.isNotEmpty)
                  Text('${filtered.length} shown',
                      style: theme.textTheme.bodySmall),
              ],
            ),
            if (breakdownList.length > 1) ...[
              const SizedBox(height: 12),
              _categoryFilter(theme, breakdownList),
            ],
            const SizedBox(height: 12),
            expensesAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.only(top: 30), child: LoadingView()),
              error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(expensesStreamProvider)),
              data: (_) {
                if (monthExpenses.isEmpty) return _empty(context);
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text('No ${_filter?.label.toLowerCase()} expenses',
                          style: theme.textTheme.bodyMedium),
                    ),
                  );
                }
                return _groupedTransactions(context, filtered, currency);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Transactions grouped by day with a per-day subtotal header.
  Widget _groupedTransactions(
      BuildContext context, List<Expense> expenses, String currency) {
    final theme = Theme.of(context);
    final groups = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      groups.putIfAbsent(key, () => []).add(e);
    }
    final dayKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    var index = 0;
    final children = <Widget>[];
    for (final day in dayKeys) {
      final items = groups[day]!;
      final dayTotal = items.fold<double>(0, (a, e) => a + e.amount);
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(
          children: [
            Text(_dayLabel(day),
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('$currency${dayTotal.toStringAsFixed(2)}',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.hintColor, fontWeight: FontWeight.w700)),
          ],
        ),
      ));
      for (final e in items) {
        children.add(_expenseTile(context, e, currency)
            .animate()
            .fadeIn(delay: (index++ * 25).ms, duration: 240.ms));
      }
    }
    return Column(children: children);
  }

  Widget _categoryFilter(
      ThemeData theme, List<MapEntry<ExpenseCategory, double>> breakdown) {
    Widget chip(String label, IconData? icon, Color color, bool selected,
        VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color : theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: selected ? color : theme.dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 15,
                      color: selected ? Colors.white : color),
                  const SizedBox(width: 6),
                ],
                Text(label,
                    style: TextStyle(
                        color: selected
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          chip('All', null, AppColors.primary, _filter == null,
              () => setState(() => _filter = null)),
          for (final entry in breakdown)
            chip(entry.key.label, entry.key.icon, entry.key.color,
                _filter == entry.key,
                () => setState(() => _filter = entry.key)),
        ],
      ),
    );
  }

  Widget _monthSwitcher(ThemeData theme) {
    return Row(
      children: [
        _roundArrow(Icons.chevron_left_rounded, () => _shiftMonth(-1)),
        Expanded(
          child: Text(
            DateUtilsX.monthYear(_month),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _roundArrow(
          Icons.chevron_right_rounded,
          _isCurrentMonth ? null : () => _shiftMonth(1),
        ),
      ],
    );
  }

  Widget _roundArrow(IconData icon, VoidCallback? onTap) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon,
              size: 22, color: onTap == null ? theme.disabledColor : null),
        ),
      ),
    );
  }

  Widget _totalCard(BuildContext context, ThemeData theme, double total,
      double budget, String currency, double projected) {
    final hasBudget = budget > 0;
    final ratio = hasBudget ? (total / budget).clamp(0.0, 1.0) : 0.0;
    final over = hasBudget && total > budget;
    final remaining = budget - total;
    // Warn when the projected month-end spend will blow the budget.
    final projectedOver =
        hasBudget && _isCurrentMonth && projected > budget && !over;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: over
              ? [AppColors.coral, AppColors.danger]
              : [AppColors.primaryLight, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow(opacity: 0.22, blur: 26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_isCurrentMonth ? 'Spent this month' : 'Spent',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: Colors.white70)),
              const Spacer(),
              InkWell(
                onTap: () => _setBudgetDialog(context, budget),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_rounded,
                          size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(hasBudget ? 'Budget' : 'Set budget',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('$currency${total.toStringAsFixed(2)}',
                style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 42)),
          ),
          if (hasBudget) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              over
                  ? 'Over budget by $currency${(-remaining).toStringAsFixed(0)} (of $currency${budget.toStringAsFixed(0)})'
                  : '$currency${remaining.toStringAsFixed(0)} left of $currency${budget.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
          // Projected month-end spend insight (current month).
          if (_isCurrentMonth && total > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                      projectedOver
                          ? Icons.trending_up_rounded
                          : Icons.insights_rounded,
                      size: 16,
                      color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      projectedOver
                          ? 'At this pace you’ll spend ~$currency${projected.toStringAsFixed(0)} — over budget'
                          : 'On track for ~$currency${projected.toStringAsFixed(0)} by month-end',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsRow(ThemeData theme, int count, double total, String currency,
      ExpenseCategory? topCategory) {
    final avg = total / (_daysForAverage == 0 ? 1 : _daysForAverage);
    Widget stat(IconData icon, String value, String label, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: softCard(context),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat(Icons.receipt_long_rounded, '$count', 'Entries',
            AppColors.primary),
        const SizedBox(width: 12),
        stat(Icons.trending_down_rounded,
            '$currency${avg.toStringAsFixed(0)}', 'Avg / day', AppColors.info),
        const SizedBox(width: 12),
        stat(
            topCategory?.icon ?? Icons.category_rounded,
            topCategory?.label ?? '—',
            'Top spend',
            topCategory?.color ?? AppColors.cancelled),
      ],
    );
  }

  Widget _breakdownCard(
      BuildContext context,
      ThemeData theme,
      List<MapEntry<ExpenseCategory, double>> breakdown,
      double total,
      String currency) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By category', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              // Donut chart.
              SizedBox(
                width: 116,
                height: 116,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: [
                      for (final e in breakdown)
                        _DonutSegment(e.value, e.key.color),
                    ],
                    trackColor: theme.dividerColor,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${breakdown.length}',
                            style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800, height: 1)),
                        Text('categories',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              // Legend.
              Expanded(
                child: Column(
                  children: [
                    for (final entry in breakdown.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: entry.key.color,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(entry.key.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall),
                            ),
                            Text(
                              total > 0
                                  ? '${(entry.value / total * 100).toStringAsFixed(0)}%'
                                  : '0%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text('$currency${entry.value.toStringAsFixed(0)}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _expenseTile(BuildContext context, Expense e, String currency) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            SizedBox(width: 6),
            Text('Delete',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      onDismissed: (_) => _deleteWithUndo(context, e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: softCard(context),
        child: InkWell(
          onTap: () => _openEditor(context, expense: e),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: e.category.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(e.category.icon, size: 20, color: e.category.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title.isEmpty ? e.category.label : e.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        '${e.category.label} · ${DateUtilsX.prettyDate(e.date)}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('$currency${e.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteWithUndo(BuildContext context, Expense e) {
    final ctrl = ref.read(expenseControllerProvider);
    ctrl.delete(e.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Text('Deleted “${e.title.isEmpty ? e.category.label : e.title}”'),
      action: SnackBarAction(
        label: 'Undo',
        // Re-add restores the content under a fresh id.
        onPressed: () => ctrl.add(Expense(
          id: 'new',
          title: e.title,
          amount: e.amount,
          category: e.category,
          date: e.date,
        )),
      ),
    ));
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: softCard(context),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              size: 42, color: AppColors.primary),
          const SizedBox(height: 12),
          Text('Nothing logged this month',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Add an expense to see it here.',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add expense'),
          ),
        ],
      ),
    );
  }

  Widget _currencyButton(BuildContext context, String current) {
    return PopupMenuButton<String>(
      tooltip: 'Currency',
      onSelected: (v) => ref.read(expenseSettingsProvider).setCurrency(v),
      itemBuilder: (_) => [
        for (final s in ['₹', '\$', '€', '£', '¥'])
          PopupMenuItem(value: s, child: Text(s)),
      ],
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.circle,
        ),
        child: Text(current,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
    );
  }

  Future<void> _setBudgetDialog(BuildContext context, double current) async {
    final controller = TextEditingController(
        text: current > 0 ? current.toStringAsFixed(0) : '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Budget amount',
            helperText: 'Set 0 to remove the budget',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim()) ?? 0;
              ref.read(expenseSettingsProvider).setBudget(v);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, {Expense? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExpenseEditorSheet(initial: expense),
    );
  }
}

/// A single slice of the category donut.
class _DonutSegment {
  final double value;
  final Color color;
  const _DonutSegment(this.value, this.color);
}

/// Paints a category-breakdown donut with rounded gaps between slices.
class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final Color trackColor;

  _DonutPainter({required this.segments, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );
    final total = segments.fold<double>(0, (a, s) => a + s.value);

    // Background track.
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (total <= 0) return;

    const gap = 0.04; // radians between slices
    var start = -math.pi / 2;
    for (final s in segments) {
      final sweep = (s.value / total) * (2 * math.pi) - gap;
      if (sweep <= 0) {
        start += (s.value / total) * (2 * math.pi);
        continue;
      }
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke;
      canvas.drawArc(rect, start + gap / 2, sweep, false, paint);
      start += (s.value / total) * (2 * math.pi);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.segments != segments || old.trackColor != trackColor;
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_rounded, size: 20, color: Colors.white),
              SizedBox(width: 6),
              Text('Add',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpenseEditorSheet extends ConsumerStatefulWidget {
  final Expense? initial;
  const ExpenseEditorSheet({super.key, this.initial});

  @override
  ConsumerState<ExpenseEditorSheet> createState() => _ExpenseEditorSheetState();
}

class _ExpenseEditorSheetState extends ConsumerState<ExpenseEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late ExpenseCategory _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _category = e?.category ?? ExpenseCategory.food;
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _bumpAmount(double delta) {
    final current = double.tryParse(_amount.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 9999999).toDouble();
    setState(() {
      _amount.text = next == next.roundToDouble()
          ? next.toStringAsFixed(0)
          : next.toStringAsFixed(2);
    });
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }
    final ctrl = ref.read(expenseControllerProvider);
    final title = _title.text.trim();
    if (widget.initial == null) {
      ctrl.add(Expense(
        id: 'new',
        title: title,
        amount: amount,
        category: _category,
        date: _date,
      ));
    } else {
      ctrl.update(widget.initial!.copyWith(
        title: title,
        amount: amount,
        category: _category,
        date: _date,
      ));
    }
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencySymbolProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(widget.initial == null ? 'Add expense' : 'Edit expense',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '$currency ',
              ),
            ),
            const SizedBox(height: 10),
            // Quick-add amount chips.
            Wrap(
              spacing: 8,
              children: [
                for (final v in [50, 100, 200, 500])
                  ActionChip(
                    label: Text('+$v'),
                    onPressed: () => _bumpAmount(v.toDouble()),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'What for? (optional)'),
            ),
            const SizedBox(height: 14),
            Text('Category', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ExpenseCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    avatar: Icon(c.icon,
                        size: 16,
                        color: _category == c ? Colors.white : c.color),
                    selected: _category == c,
                    selectedColor: c.color,
                    labelStyle: TextStyle(
                        color: _category == c ? Colors.white : null,
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: theme.hintColor),
                    const SizedBox(width: 10),
                    Text(DateUtilsX.prettyDate(_date),
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.initial != null)
                  IconButton(
                    onPressed: () {
                      ref
                          .read(expenseControllerProvider)
                          .delete(widget.initial!.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger),
                  ),
                Expanded(
                  child: FilledButton(
                      onPressed: _save, child: const Text('Save')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
