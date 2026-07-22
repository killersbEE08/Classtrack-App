import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
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
    setState(() => _month = DateTime(_month.year, _month.month + delta));
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
            _totalCard(context, theme, total, budget, currency),
            const SizedBox(height: 14),
            _statsRow(theme, monthExpenses.length, total, currency),
            const SizedBox(height: 20),
            if (breakdownList.isNotEmpty) ...[
              _breakdownCard(context, theme, breakdownList, total, currency),
              const SizedBox(height: 20),
            ],
            Text('Transactions', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            expensesAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.only(top: 30), child: LoadingView()),
              error: (e, _) => ErrorView(error: e),
              data: (_) {
                if (monthExpenses.isEmpty) return _empty(context);
                return Column(
                  children: [
                    for (var i = 0; i < monthExpenses.length; i++)
                      _expenseTile(context, monthExpenses[i], currency)
                          .animate()
                          .fadeIn(delay: (i * 30).ms, duration: 260.ms),
                  ],
                );
              },
            ),
          ],
        ),
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
              size: 22,
              color: onTap == null ? theme.disabledColor : null),
        ),
      ),
    );
  }

  Widget _totalCard(BuildContext context, ThemeData theme, double total,
      double budget, String currency) {
    final hasBudget = budget > 0;
    final ratio = hasBudget ? (total / budget).clamp(0.0, 1.0) : 0.0;
    final over = hasBudget && total > budget;
    final remaining = budget - total;
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Spent this month',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: Colors.white70)),
              const Spacer(),
              InkWell(
                onTap: () => _setBudgetDialog(context, budget),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
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
        ],
      ),
    );
  }

  Widget _statsRow(
      ThemeData theme, int count, double total, String currency) {
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
            '$currency${avg.toStringAsFixed(0)}', 'Avg / day',
            AppColors.info),
      ],
    );
  }

  Widget _breakdownCard(BuildContext context, ThemeData theme,
      List<MapEntry<ExpenseCategory, double>> breakdown, double total,
      String currency) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By category', style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          for (final entry in breakdown) ...[
            Row(
              children: [
                Icon(entry.key.icon, size: 16, color: entry.key.color),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(entry.key.label,
                        style: theme.textTheme.bodyMedium)),
                Text('$currency${entry.value.toStringAsFixed(0)}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total > 0 ? (entry.value / total).clamp(0, 1) : 0,
                minHeight: 7,
                backgroundColor: entry.key.color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(entry.key.color),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _expenseTile(BuildContext context, Expense e, String currency) {
    final theme = Theme.of(context);
    return Container(
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
              child: Icon(e.category.icon, size: 20, color: e.category.color),
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
                  Text('${e.category.label} · ${DateUtilsX.prettyDate(e.date)}',
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
    );
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
          Text('Nothing logged this month', style: theme.textTheme.titleMedium),
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
  ConsumerState<ExpenseEditorSheet> createState() =>
      _ExpenseEditorSheetState();
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
