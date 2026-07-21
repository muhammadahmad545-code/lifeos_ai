class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.isIncome = false,
    this.tags = const <String>[],
    this.createdAt,
  });

  final String id;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final bool isIncome;
  final List<String> tags;
  final DateTime? createdAt;

  Expense copyWith({
    String? id,
    String? description,
    double? amount,
    String? category,
    DateTime? date,
    bool? isIncome,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      isIncome: isIncome ?? this.isIncome,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Budget {
  const Budget({
    required this.id,
    required this.category,
    required this.limitAmount,
    this.spentAmount = 0,
    required this.month,
  });

  final String id;
  final String category;
  final double limitAmount;
  final double spentAmount;
  final DateTime month;

  Budget copyWith({
    String? id,
    String? category,
    double? limitAmount,
    double? spentAmount,
    DateTime? month,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      limitAmount: limitAmount ?? this.limitAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      month: month ?? this.month,
    );
  }
}

class ExpenseTotals {
  const ExpenseTotals({
    required this.income,
    required this.expense,
  });

  final double income;
  final double expense;

  double get net => income - expense;
}
