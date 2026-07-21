import 'expense.dart';

abstract class ExpenseRepository {
  Stream<List<Expense>> watchExpenses(String userId);

  Future<List<Expense>> getExpenses(String userId);

  Future<Expense> createExpense(String userId, Expense expense);

  Future<Expense> updateExpense(Expense expense);

  Future<void> deleteExpense(String expenseId);

  Future<ExpenseTotals> getTotals(String userId, DateTime month);

  Stream<List<Budget>> watchBudgets(String userId);

  Future<Budget> upsertBudget(String userId, Budget budget);
}
