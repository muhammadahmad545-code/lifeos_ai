import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/receipt_text_parser.dart';
import '../../../core/utils/media_path_helper.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/premium_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../domain/expense.dart';

const List<Color> _chartColors = <Color>[
  Color(0xFF2563EB),
  Color(0xFF0D9488),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF64748B),
];

const List<String> _expenseCategories = <String>[
  'Food',
  'Transport',
  'Housing',
  'Utilities',
  'Shopping',
  'Health',
  'Entertainment',
  'Education',
  'Salary',
  'Other',
];

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _delete(Expense expense) async {
    try {
      await ref.read(expenseRepositoryProvider).deleteExpense(expense.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openForm({Expense? expense, bool isIncome = false}) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final Expense? result = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _ExpenseFormSheet(initial: expense, isIncome: isIncome),
    );
    if (result == null) {
      return;
    }
    try {
      if (expense == null) {
        await ref.read(expenseRepositoryProvider).createExpense(userId, result);
      } else {
        await ref.read(expenseRepositoryProvider).updateExpense(result);
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _setBudget(List<Budget> existing) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final Budget? result = await showModalBottomSheet<Budget>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const _BudgetFormSheet(),
    );
    if (result == null) {
      return;
    }
    try {
      await ref.read(expenseRepositoryProvider).upsertBudget(userId, result);
    } catch (error) {
      _showError(error);
    }
  }

  void _showAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.green),
              title: const Text('Add income'),
              onTap: () {
                Navigator.pop(context);
                _openForm(isIncome: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.red),
              title: const Text('Add expense'),
              onTap: () {
                Navigator.pop(context);
                _openForm(isIncome: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Expense>> expensesAsync = ref.watch(watchExpensesProvider);
    final AsyncValue<List<Budget>> budgetsAsync = ref.watch(watchBudgetsProvider);
    final DateTime now = DateTime.now();
    final NumberFormat money = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: expensesAsync.when(
        data: (List<Expense> expenses) {
          final List<Expense> monthExpenses =
              expenses.where((Expense e) => e.date.year == now.year && e.date.month == now.month).toList();
          final double income = monthExpenses.where((Expense e) => e.isIncome).fold(0.0, (double s, Expense e) => s + e.amount);
          final double spent = monthExpenses.where((Expense e) => !e.isIncome).fold(0.0, (double s, Expense e) => s + e.amount);

          final Map<String, double> byCategory = <String, double>{};
          for (final Expense e in monthExpenses.where((Expense e) => !e.isIncome)) {
            byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
          }
          final List<MapEntry<String, double>> ranked = byCategory.entries.toList()
            ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));

          final List<Expense> sorted = List<Expense>.from(expenses)..sort((Expense a, Expense b) => b.date.compareTo(a.date));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(watchExpensesProvider);
              ref.invalidate(watchBudgetsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: _TotalCard(label: 'Income', value: money.format(income), color: Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _TotalCard(label: 'Expenses', value: money.format(spent), color: Colors.red)),
                    const SizedBox(width: 12),
                    Expanded(child: _TotalCard(label: 'Net', value: money.format(income - spent), color: (income - spent) >= 0 ? Colors.blue : Colors.orange)),
                  ],
                ),
                const SizedBox(height: 24),
                if (ranked.isNotEmpty) ...<Widget>[
                  const SectionHeader(title: 'Spending by category'),
                  const SizedBox(height: 12),
                  PremiumCard(
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 42,
                              sections: List<PieChartSectionData>.generate(
                                ranked.take(6).length,
                                (int i) {
                                  final MapEntry<String, double> entry = ranked[i];
                                  final double pct = spent <= 0 ? 0 : entry.value / spent;
                                  return PieChartSectionData(
                                    color: _chartColors[i % _chartColors.length],
                                    value: entry.value,
                                    title: '${(pct * 100).round()}%',
                                    radius: 54,
                                    titleStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...List<Widget>.generate(ranked.take(6).length, (int i) {
                          final MapEntry<String, double> entry = ranked[i];
                          final double pct = spent <= 0 ? 0 : entry.value / spent;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _chartColors[i % _chartColors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(entry.key)),
                                Text('${money.format(entry.value)} (${(pct * 100).round()}%)'),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const SectionHeader(title: 'Budgets'),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      onPressed: () => _setBudget(budgetsAsync.valueOrNull ?? const []),
                      label: const Text('Set budget'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                budgetsAsync.when(
                  data: (List<Budget> budgets) {
                    final List<Budget> thisMonth = budgets.where((Budget b) => b.month.year == now.year && b.month.month == now.month).toList();
                    if (thisMonth.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No budgets set for this month.'),
                      );
                    }
                    return Column(
                      children: thisMonth.map((Budget b) {
                        final double spentInCategory = byCategory[b.category] ?? 0;
                        final double ratio = b.limitAmount <= 0 ? 0 : (spentInCategory / b.limitAmount).clamp(0, 1.5);
                        final bool over = spentInCategory > b.limitAmount;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PremiumCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text(b.category, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text('${money.format(spentInCategory)} / ${money.format(b.limitAmount)}',
                                        style: TextStyle(color: over ? Colors.red : null)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: ratio > 1 ? 1 : ratio,
                                    minHeight: 8,
                                    color: over ? Colors.red : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
                  error: (Object error, StackTrace stack) => Text('Error: $error'),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Transactions'),
                const SizedBox(height: 12),
                if (sorted.isEmpty)
                  const EmptyStateView(title: 'No transactions yet', message: 'Tap the + button to log income or an expense.')
                else
                  ...sorted.map((Expense expense) {
                    final Color color = expense.isIncome ? Colors.green : Colors.red;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _openForm(expense: expense, isIncome: expense.isIncome),
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(expense.isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color),
                        ),
                        title: Text(expense.description),
                        subtitle: Text(
                          '${expense.category} · ${DateFormat.MMMd().format(expense.date)}'
                          '${expense.receiptPath != null ? ' · receipt' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '${expense.isIncome ? '+' : '-'}${money.format(expense.amount)}',
                              style: TextStyle(color: color, fontWeight: FontWeight.bold),
                            ),
                            IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _delete(expense)),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ExpenseFormSheet extends ConsumerStatefulWidget {
  const _ExpenseFormSheet({this.initial, required this.isIncome});

  final Expense? initial;
  final bool isIncome;

  @override
  ConsumerState<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<_ExpenseFormSheet> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late String _category;
  late DateTime _date;
  late bool _isIncome;
  String? _receiptPath;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    final Expense? e = widget.initial;
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _amountController = TextEditingController(text: e != null ? e.amount.toStringAsFixed(2) : '');
    _category = e?.category ?? _expenseCategories.first;
    _date = e?.date ?? DateTime.now();
    _isIncome = e?.isIncome ?? widget.isIncome;
    _receiptPath = e?.receiptPath;
  }

  Future<void> _pickReceipt(ImageSource source, {required bool runOcr}) async {
    final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) {
      return;
    }
    final File copied = await MediaPathHelper.copyInto(
      sourcePath: picked.path,
      folder: 'receipts',
      extension: 'jpg',
    );
    setState(() {
      _receiptPath = copied.path;
      _isIncome = false;
    });
    if (!runOcr) {
      return;
    }
    setState(() => _scanning = true);
    try {
      final ReceiptParseResult parsed = await ref.read(ocrServiceProvider).scanReceipt(copied.path);
      if (!mounted) {
        return;
      }
      if (parsed.description != null && _descriptionController.text.trim().isEmpty) {
        _descriptionController.text = parsed.description!;
      }
      if (parsed.amount != null) {
        _amountController.text = parsed.amount!.toStringAsFixed(2);
      }
      if (parsed.category != null && _expenseCategories.contains(parsed.category)) {
        setState(() => _category = parsed.category!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parsed.rawText.isEmpty
                ? 'No text found on receipt.'
                : 'Scanned receipt${parsed.amount != null ? ' · \$${parsed.amount!.toStringAsFixed(2)}' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OCR failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _submit() {
    final double? amount = double.tryParse(_amountController.text.trim());
    if (_descriptionController.text.trim().isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a description and a valid amount.')));
      return;
    }
    final Expense result = (widget.initial ?? Expense(id: '', description: '', amount: 0, category: _category, date: _date)).copyWith(
      description: _descriptionController.text.trim(),
      amount: amount,
      category: _category,
      date: _date,
      isIncome: _isIncome,
      receiptPath: _receiptPath,
      clearReceipt: _receiptPath == null,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initial != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(isEditing ? 'Edit transaction' : (_isIncome ? 'Add income' : 'Add expense'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('Expense'), icon: Icon(Icons.arrow_upward)),
                ButtonSegment<bool>(value: true, label: Text('Income'), icon: Icon(Icons.arrow_downward)),
              ],
              selected: <bool>{_isIncome},
              onSelectionChanged: (Set<bool> value) => setState(() => _isIncome = value.first),
            ),
            const SizedBox(height: 16),
            TextField(controller: _descriptionController, autofocus: !isEditing, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('expense-category-$_category'),
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _expenseCategories.map((String c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
              onChanged: (String? value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: _pickDate,
              label: Text(DateFormat.yMMMd().format(_date)),
            ),
            if (!_isIncome) ...<Widget>[
              const SizedBox(height: 12),
              if (_receiptPath != null) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_receiptPath!), height: 140, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.tonalIcon(
                onPressed: _scanning ? null : () => _pickReceipt(ImageSource.camera, runOcr: true),
                icon: _scanning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(_scanning ? 'Scanning…' : 'Scan receipt (OCR)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: _scanning ? null : () => _pickReceipt(ImageSource.camera, runOcr: false),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: _scanning ? null : () => _pickReceipt(ImageSource.gallery, runOcr: true),
                      label: const Text('Gallery OCR'),
                    ),
                  ),
                  if (_receiptPath != null) ...<Widget>[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove receipt',
                      onPressed: () => setState(() => _receiptPath = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(isEditing ? 'Save changes' : 'Save')),
          ],
        ),
      ),
    );
  }
}

class _BudgetFormSheet extends StatefulWidget {
  const _BudgetFormSheet();

  @override
  State<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<_BudgetFormSheet> {
  final TextEditingController _limitController = TextEditingController();
  String _category = _expenseCategories.first;

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _submit() {
    final double? limit = double.tryParse(_limitController.text.trim());
    if (limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid budget amount.')));
      return;
    }
    Navigator.of(context).pop(Budget(id: '', category: _category, limitAmount: limit, month: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Set monthly budget', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('budget-category-$_category'),
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _expenseCategories.map((String c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
              onChanged: (String? value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limitController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monthly limit', prefixText: '\$ '),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Save budget')),
          ],
        ),
      ),
    );
  }
}
