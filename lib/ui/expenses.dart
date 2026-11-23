import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/assistant.dart';
import '../logic/dates.dart';
import '../logic/rules.dart';
import '../providers.dart';
import 'common.dart';

IconData categoryIcon(String c) => switch (c) {
      'Food' => Icons.restaurant_rounded,
      'Groceries' => Icons.local_grocery_store_outlined,
      'Transport' => Icons.directions_car_outlined,
      'Shopping' => Icons.shopping_bag_outlined,
      'Bills' => Icons.receipt_long_outlined,
      'Health' => Icons.favorite_outline_rounded,
      'Entertainment' => Icons.movie_outlined,
      'Education' => Icons.school_outlined,
      'Salary' => Icons.work_outline_rounded,
      'Freelance' => Icons.laptop_mac_rounded,
      'Gift' => Icons.card_giftcard_rounded,
      _ => Icons.payments_outlined,
    };

bool inMonth(DateTime d, DateTime month) => d.year == month.year && d.month == month.month;

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  DateTime _month = monthStart(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final money = ref.watch(moneyProvider);
    final all = ref.watch(expensesProvider).list;
    final budgets = effectiveBudgets(ref.watch(budgetsProvider).list, _month);
    final rows = all.where((e) => inMonth(e.date, _month)).toList();
    final spent = rows.where((e) => !e.isIncome).fold<double>(0, (s, e) => s + e.amount);
    final income = rows.where((e) => e.isIncome).fold<double>(0, (s, e) => s + e.amount);

    final trendMonths = [for (var i = -5; i <= 0; i++) addMonths(_month, i)];
    final trend = [
      for (final m in trendMonths)
        all.where((e) => !e.isIncome && inMonth(e.date, m)).fold<double>(0, (s, e) => s + e.amount),
    ];

    final byCat = <String, double>{};
    for (final e in rows.where((e) => !e.isIncome)) {
      byCat[e.category] = (byCat[e.category] ?? 0.0) + e.amount;
    }
    final cats = {...byCat.keys, ...budgets.keys}.toList()..sort((a, b) => (byCat[b] ?? 0).compareTo(byCat[a] ?? 0));

    final byDay = <String, List<ExpenseRow>>{};
    for (final e in rows) {
      byDay.putIfAbsent(dayKey(e.date), () => []).add(e);
    }
    final isCurrent = _month == monthStart(DateTime.now());
    final recurring = ref.watch(recurringProvider).list;

    return SubPage(
      title: 'Expenses',
      subtitle: DateFormat('MMMM y').format(_month),
      headerActions: [
        IconAction(icon: Icons.chevron_left_rounded, label: 'Previous month', onPressed: () => setState(() => _month = addMonths(_month, -1))),
        IconAction(
          icon: Icons.chevron_right_rounded,
          label: 'Next month',
          onPressed: isCurrent ? null : () => setState(() => _month = addMonths(_month, 1)),
        ),
      ],
      floating: AddButton(
        label: 'Add expense',
        onPressed: () => push(context, ExpenseEditor(initialDate: isCurrent ? null : _month)),
      ),
      children: [
        BCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spent this month', style: BasaltType.label.copyWith(color: p.textMuted)),
              const SizedBox(height: Gap.xs),
              Text(money(spent), style: BasaltType.hero.copyWith(color: p.text)),
              const SizedBox(height: Gap.sm),
              Text(
                income > 0 ? 'Income ${money(income)} · Net ${money(income - spent)}' : '${rows.length} ${rows.length == 1 ? 'entry' : 'entries'}',
                style: BasaltType.caption.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: Gap.lg),
              BBars(
                values: trend,
                labels: [for (final m in trendMonths) DateFormat('MMM').format(m)],
                highlight: 5,
                height: 84,
              ),
            ],
          ),
        ),
        BSectionTitle('Categories', action: 'Set budget', onAction: () => _editBudget(context, ref, _month, budgets)),
        if (cats.isEmpty)
          BCard(child: Text('Spending by category appears here.', style: BasaltType.body.copyWith(color: p.textMuted)))
        else
          BGroup(
            children: [
              for (final c in cats) _CategoryRow(category: c, spent: byCat[c] ?? 0, limit: budgets[c], total: spent),
            ],
          ),
        if (recurring.isNotEmpty) ...[
          const BSectionTitle('Recurring'),
          BGroup(children: [for (final r in recurring) _RecurringTile(rule: r)]),
        ],
        const BSectionTitle('Transactions'),
        if (rows.isEmpty)
          BEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Nothing recorded',
            message: 'Add what you spend and earn to see your monthly totals.',
            actionLabel: 'Add expense',
            onAction: () => push(context, ExpenseEditor(initialDate: isCurrent ? null : _month)),
          )
        else
          for (final d in byDay.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.sm, Gap.xs, Gap.xs),
              child: Text(relativeDay(parseDayKey(d.key)!), style: BasaltType.label.copyWith(color: p.textMuted)),
            ),
            BGroup(children: [for (final e in d.value) _ExpenseTile(expense: e)]),
          ],
      ],
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.category, required this.spent, required this.limit, required this.total});

  final String category;
  final double spent;
  final double? limit;
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.basalt;
    final money = ref.watch(moneyProvider);
    final l = limit;
    final over = l != null && spent > l;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BIconTile(categoryIcon(category), size: 32),
              const SizedBox(width: Gap.md),
              Expanded(child: Text(category, style: BasaltType.bodyStrong.copyWith(color: p.text))),
              Text(money(spent), style: BasaltType.bodyStrong.copyWith(color: over ? p.danger : p.text)),
            ],
          ),
          const SizedBox(height: Gap.sm),
          BProgressBar(
            value: l != null ? (l <= 0 ? 0 : spent / l) : (total <= 0 ? 0 : spent / total),
            color: over ? p.danger : (l != null && spent >= l * 0.8 ? p.warning : null),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            l == null
                ? '${total <= 0 ? 0 : (spent / total * 100).round()}% of spending'
                : (over ? '${money(spent - l)} over the ${money(l)} budget' : '${money(l - spent)} left of ${money(l)}'),
            style: BasaltType.caption.copyWith(color: over ? p.danger : p.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.expense});

  final ExpenseRow expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.basalt;
    final money = ref.watch(moneyProvider);
    return BListRow(
      icon: categoryIcon(expense.category),
      iconColor: expense.isIncome ? p.success : null,
      title: expense.description,
      subtitle: expense.recurringId == null ? expense.category : '${expense.category} · Recurring',
      trailing: Text(
        expense.isIncome ? '+${money(expense.amount)}' : money(expense.amount),
        style: BasaltType.bodyStrong.copyWith(color: expense.isIncome ? p.success : p.text),
      ),
      onTap: () => push(context, ExpenseEditor(expense: expense)),
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({required this.rule});

  final RecurringRow rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.basalt;
    final money = ref.watch(moneyProvider);
    final next = recurringOccurrence(rule.startDate, rule.frequency, rule.nextIndex);
    return BListRow(
      icon: categoryIcon(rule.category),
      iconColor: rule.isPaused ? p.textFaint : (rule.isIncome ? p.success : null),
      title: rule.description,
      subtitle: rule.isPaused
          ? '${frequencyLabel(rule.frequency)} · Paused'
          : '${recurringScheduleLabel(rule.startDate, rule.frequency)} · next ${relativeDay(next)}',
      trailing: Text(
        rule.isIncome ? '+${money(rule.amount)}' : money(rule.amount),
        style: BasaltType.bodyStrong.copyWith(color: rule.isPaused ? p.textFaint : (rule.isIncome ? p.success : p.text)),
      ),
      onTap: () => _manageRecurring(context, ref, rule),
    );
  }
}

Future<void> _manageRecurring(BuildContext context, WidgetRef ref, RecurringRow rule) async {
  final repo = ref.read(repoProvider);
  await showFormSheet<void>(
    context,
    title: rule.description,
    builder: (ctx) {
      final p = ctx.basalt;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${recurringScheduleLabel(rule.startDate, rule.frequency)}, ${rule.isIncome ? 'income' : 'expense'} of '
            '${ref.read(moneyProvider)(rule.amount)} in ${rule.category}. It is added on its day, or the next time '
            'you open Plania if the phone was off.',
            style: BasaltType.body.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: Gap.lg),
          BButton(
            label: rule.isPaused ? 'Resume' : 'Pause',
            icon: rule.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            variant: BButtonVariant.secondary,
            expand: true,
            onPressed: () async {
              await repo.setRecurringPaused(rule.id, !rule.isPaused);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
          const SizedBox(height: Gap.sm),
          BButton(
            label: 'Delete recurring entry',
            icon: Icons.delete_outline_rounded,
            variant: BButtonVariant.danger,
            expand: true,
            onPressed: () async {
              final ok = await bConfirm(
                ctx,
                title: 'Stop repeating "${rule.description}"?',
                message: 'Entries already added stay in your history.',
                confirmLabel: 'Delete',
                danger: true,
              );
              if (!ok) return;
              await repo.deleteRecurring(rule.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> _editBudget(BuildContext context, WidgetRef ref, DateTime month, Map<String, double> current) async {
  var category = kExpenseCategories.first;
  final amount = TextEditingController(text: current[category]?.toStringAsFixed(0) ?? '');
  await showFormSheet<void>(
    context,
    title: 'Monthly budget',
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Applies from ${DateFormat('MMMM y').format(month)} onwards.',
            style: BasaltType.caption.copyWith(color: ctx.basalt.textMuted),
          ),
          const SizedBox(height: Gap.md),
          ChipWrap(
            children: [
              for (final c in kExpenseCategories)
                BChip(
                  label: c,
                  selected: category == c,
                  onTap: () => setSheet(() {
                    category = c;
                    amount.text = current[c]?.toStringAsFixed(0) ?? '';
                  }),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: 'Limit for $category', prefixText: '${ref.read(moneyProvider).symbol} '),
          ),
          const SizedBox(height: Gap.lg),
          BButton(
            label: 'Save budget',
            expand: true,
            onPressed: () async {
              final v = parseAmount(amount.text);
              if (v == null) {
                BToast.show(ctx, 'Enter an amount above zero');
                return;
              }
              await ref.read(repoProvider).setBudget(category, month, v);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
          if (current.containsKey(category)) ...[
            const SizedBox(height: Gap.sm),
            BButton(
              label: 'Remove $category budget',
              variant: BButtonVariant.ghost,
              expand: true,
              onPressed: () async {
                await ref.read(repoProvider).setBudget(category, month, 0);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ],
        ],
      ),
    ),
  );
}

class ExpenseEditor extends ConsumerStatefulWidget {
  const ExpenseEditor({super.key, this.expense, this.initialDate});

  final ExpenseRow? expense;
  final DateTime? initialDate;

  @override
  ConsumerState<ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<ExpenseEditor> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.expense == null ? '' : widget.expense!.amount.toStringAsFixed(2),
  );
  late final TextEditingController _desc = TextEditingController(text: widget.expense?.description ?? '');
  late bool _income = widget.expense?.isIncome ?? false;
  late String _category = widget.expense?.category ?? kExpenseCategories.first;
  late DateTime _date = widget.expense?.date ?? widget.initialDate ?? DateTime.now();
  // 'none', 'weekly' or 'monthly'.
  String _repeat = 'none';
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      BToast.show(context, 'Enter an amount above zero');
      return;
    }
    setState(() => _saving = true);
    final desc = _desc.text.trim().isEmpty ? _category : _desc.text.trim();
    final repo = ref.read(repoProvider);
    final existing = widget.expense;
    if (existing == null && _repeat != 'none') {
      // The rule posts the first entry itself when its day has come.
      await repo.addRecurring(
        description: desc,
        amount: amount,
        category: _category,
        isIncome: _income,
        frequency: _repeat,
        start: _date,
      );
    } else {
      await repo.saveExpense(
        id: existing?.id,
        description: desc,
        amount: amount,
        category: _category,
        date: _date,
        isIncome: _income,
      );
      if (existing != null && _repeat != 'none') {
        final saved = await repo.expense(existing.id);
        if (saved != null) await repo.makeRecurring(saved, _repeat);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await bConfirm(context, title: 'Delete this entry?', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    await ref.read(repoProvider).deleteExpense(widget.expense!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(moneyProvider);
    final cats = _income ? kIncomeCategories : kExpenseCategories;
    final shownCats = cats.contains(_category) ? cats : [...cats, _category];
    return EditorScaffold(
      title: widget.expense == null ? (_income ? 'Add income' : 'Add expense') : 'Edit entry',
      onSave: _saving ? null : _save,
      actions: [
        if (widget.expense != null) IconAction(icon: Icons.delete_outline_rounded, label: 'Delete entry', onPressed: _delete),
      ],
      children: [
        TextField(
          controller: _amount,
          autofocus: widget.expense == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(labelText: 'Amount', prefixText: '${money.symbol} '),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _desc,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Lunch with Sara'),
        ),
        const FieldLabel('Type'),
        ChipWrap(
          children: [
            BChip(
              label: 'Expense',
              selected: !_income,
              onTap: () => setState(() {
                _income = false;
                if (!kExpenseCategories.contains(_category)) _category = kExpenseCategories.first;
              }),
            ),
            BChip(
              label: 'Income',
              selected: _income,
              onTap: () => setState(() {
                _income = true;
                if (!kIncomeCategories.contains(_category)) _category = kIncomeCategories.first;
              }),
            ),
          ],
        ),
        const FieldLabel('Date'),
        PickerField(
          icon: Icons.event_rounded,
          label: relativeDay(_date),
          onTap: () async {
            final d = await pickDate(context, _date);
            if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, 12));
          },
        ),
        const FieldLabel('Repeat'),
        if (widget.expense?.recurringId != null)
          Text(
            'Added by a recurring entry. Pause or delete it under Recurring on the Expenses screen.',
            style: BasaltType.caption.copyWith(color: context.basalt.textMuted),
          )
        else ...[
          ChipWrap(
            children: [
              for (final (value, label) in [('none', 'Never'), ('weekly', 'Weekly'), ('monthly', 'Monthly')])
                BChip(label: label, selected: _repeat == value, onTap: () => setState(() => _repeat = value)),
            ],
          ),
          if (_repeat != 'none') ...[
            const SizedBox(height: Gap.sm),
            Text(
              '${recurringScheduleLabel(_date, _repeat)}. Each one is added on its day.',
              style: BasaltType.caption.copyWith(color: context.basalt.textMuted),
            ),
          ],
        ],
        const FieldLabel('Category'),
        ChipWrap(
          children: [
            for (final c in shownCats)
              BChip(label: c, icon: categoryIcon(c), selected: _category == c, onTap: () => setState(() => _category = c)),
          ],
        ),
      ],
    );
  }
}
