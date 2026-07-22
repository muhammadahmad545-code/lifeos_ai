import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/list_codec.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Expense>> watchExpenses(String userId) {
    final query = (_db.select(_db.expenses)
          ..where((Expenses tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Expenses)>[
            (Expenses tbl) => OrderingTerm.desc(tbl.date),
          ]))
        .watch();
    return query.map((List<ExpenseRow> rows) => rows.map(_mapExpense).toList());
  }

  @override
  Future<List<Expense>> getExpenses(String userId) async {
    final List<ExpenseRow> rows = await (_db.select(_db.expenses)
          ..where((Expenses tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Expenses)>[
            (Expenses tbl) => OrderingTerm.desc(tbl.date),
          ]))
        .get();
    return rows.map(_mapExpense).toList();
  }

  @override
  Future<Expense> createExpense(String userId, Expense expense) async {
    final String id = expense.id.isEmpty ? IdGenerator.next() : expense.id;
    final DateTime now = DateTime.now();
    await _db.into(_db.expenses).insert(
          ExpensesCompanion.insert(
            id: id,
            userId: userId,
            description: expense.description,
            amount: expense.amount,
            category: expense.category,
            date: expense.date,
            isIncome: Value<bool>(expense.isIncome),
            tags: Value<String>(ListCodec.encode(expense.tags)),
            receiptPath: Value<String?>(expense.receiptPath),
            createdAt: expense.createdAt ?? now,
          ),
        );
    final ExpenseRow row = await (_db.select(_db.expenses)..where((Expenses tbl) => tbl.id.equals(id))).getSingle();
    return _mapExpense(row);
  }

  @override
  Future<Expense> updateExpense(Expense expense) async {
    await (_db.update(_db.expenses)..where((Expenses tbl) => tbl.id.equals(expense.id))).write(
          ExpensesCompanion(
            description: Value<String>(expense.description),
            amount: Value<double>(expense.amount),
            category: Value<String>(expense.category),
            date: Value<DateTime>(expense.date),
            isIncome: Value<bool>(expense.isIncome),
            tags: Value<String>(ListCodec.encode(expense.tags)),
            receiptPath: Value<String?>(expense.receiptPath),
          ),
        );
    final ExpenseRow row =
        await (_db.select(_db.expenses)..where((Expenses tbl) => tbl.id.equals(expense.id))).getSingle();
    return _mapExpense(row);
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    await (_db.delete(_db.expenses)..where((Expenses tbl) => tbl.id.equals(expenseId))).go();
  }

  @override
  Future<ExpenseTotals> getTotals(String userId, DateTime month) async {
    final DateTime start = DateTime(month.year, month.month);
    final DateTime end = DateTime(month.year, month.month + 1);
    final List<ExpenseRow> rows = await (_db.select(_db.expenses)
          ..where(
            (Expenses tbl) =>
                tbl.userId.equals(userId) &
                tbl.date.isBiggerOrEqualValue(start) &
                tbl.date.isSmallerThanValue(end),
          ))
        .get();

    double income = 0;
    double expense = 0;
    for (final ExpenseRow row in rows) {
      if (row.isIncome) {
        income += row.amount;
      } else {
        expense += row.amount;
      }
    }
    return ExpenseTotals(income: income, expense: expense);
  }

  @override
  Stream<List<Budget>> watchBudgets(String userId) {
    final query = (_db.select(_db.budgets)
          ..where((Budgets tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Budgets)>[
            (Budgets tbl) => OrderingTerm.desc(tbl.month),
            (Budgets tbl) => OrderingTerm(expression: tbl.category),
          ]))
        .watch();
    return query.map((List<BudgetRow> rows) => rows.map(_mapBudget).toList());
  }

  @override
  Future<Budget> upsertBudget(String userId, Budget budget) async {
    final DateTime monthStart = DateTime(budget.month.year, budget.month.month);
    final BudgetRow? existing = await (_db.select(_db.budgets)
          ..where(
            (Budgets tbl) =>
                tbl.userId.equals(userId) &
                tbl.category.equals(budget.category) &
                tbl.month.equals(monthStart),
          ))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.budgets)..where((Budgets tbl) => tbl.id.equals(existing.id))).write(
            BudgetsCompanion(
              limitAmount: Value<double>(budget.limitAmount),
              spentAmount: Value<double>(budget.spentAmount),
            ),
          );
      final BudgetRow row =
          await (_db.select(_db.budgets)..where((Budgets tbl) => tbl.id.equals(existing.id))).getSingle();
      return _mapBudget(row);
    }

    final String id = budget.id.isEmpty ? IdGenerator.next() : budget.id;
    await _db.into(_db.budgets).insert(
          BudgetsCompanion.insert(
            id: id,
            userId: userId,
            category: budget.category,
            limitAmount: budget.limitAmount,
            spentAmount: Value<double>(budget.spentAmount),
            month: monthStart,
          ),
        );
    final BudgetRow row = await (_db.select(_db.budgets)..where((Budgets tbl) => tbl.id.equals(id))).getSingle();
    return _mapBudget(row);
  }

  Expense _mapExpense(ExpenseRow row) {
    return Expense(
      id: row.id,
      description: row.description,
      amount: row.amount,
      category: row.category,
      date: row.date,
      isIncome: row.isIncome,
      tags: ListCodec.decode(row.tags),
      receiptPath: row.receiptPath,
      createdAt: row.createdAt,
    );
  }

  Budget _mapBudget(BudgetRow row) {
    return Budget(
      id: row.id,
      category: row.category,
      limitAmount: row.limitAmount,
      spentAmount: row.spentAmount,
      month: row.month,
    );
  }
}
