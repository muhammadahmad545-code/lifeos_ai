import 'package:flutter_test/flutter_test.dart';
import 'package:plania/data/database.dart';
import 'package:plania/logic/assistant.dart';
import 'package:plania/logic/dates.dart';
import 'package:plania/logic/rules.dart';

TaskRow task(String title, {DateTime? due, int priority = 1, bool done = false, String? parent}) {
  final now = DateTime(2026, 11, 17, 8);
  return TaskRow(
    id: title,
    userId: kLocalUserId,
    title: title,
    isCompleted: done,
    dueDate: due,
    priority: priority,
    labels: '',
    parentId: parent,
    isRecurring: false,
    recurrence: 'none',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('dates', () {
    test('day keys round-trip', () {
      final d = DateTime(2026, 3, 9);
      expect(dayKey(d), '2026-03-09');
      expect(parseDayKey('2026-03-09'), d);
      expect(parseDayKey('garbage'), isNull);
    });

    test('daysBetween ignores time of day', () {
      expect(daysBetween(DateTime(2026, 1, 1, 23), DateTime(2026, 1, 2, 1)), 1);
      expect(daysBetween(DateTime(2026, 1, 2), DateTime(2026, 1, 1)), -1);
    });

    test('relative day labels', () {
      final now = DateTime(2026, 11, 17, 10);
      expect(relativeDay(DateTime(2026, 11, 17, 22), now: now), 'Today');
      expect(relativeDay(DateTime(2026, 11, 18), now: now), 'Tomorrow');
      expect(relativeDay(DateTime(2026, 11, 16), now: now), 'Yesterday');
    });
  });

  group('recurrence', () {
    test('monthly clamps to the end of short months', () {
      expect(nextDue(DateTime(2026, 1, 31, 9), 'monthly'), DateTime(2026, 2, 28, 9));
      expect(nextDue(DateTime(2028, 1, 31), 'monthly'), DateTime(2028, 2, 29));
      expect(nextDue(DateTime(2026, 12, 15), 'monthly'), DateTime(2027, 1, 15));
    });

    test('weekdays skip the weekend', () {
      // 2026-11-20 is a Friday.
      expect(nextDue(DateTime(2026, 11, 20), 'weekdays'), DateTime(2026, 11, 23));
      expect(nextDue(DateTime(2026, 11, 17), 'weekdays'), DateTime(2026, 11, 18));
    });

    test('daily, weekly, yearly', () {
      expect(nextDue(DateTime(2026, 11, 17), 'daily'), DateTime(2026, 11, 18));
      expect(nextDue(DateTime(2026, 11, 17), 'weekly'), DateTime(2026, 11, 24));
      expect(nextDue(DateTime(2028, 2, 29), 'yearly'), DateTime(2029, 2, 28));
    });

    test('due buckets', () {
      final now = DateTime(2026, 11, 17, 12);
      expect(dueBucket(null, now), DueBucket.someday);
      expect(dueBucket(DateTime(2026, 11, 16, 23), now), DueBucket.overdue);
      expect(dueBucket(DateTime(2026, 11, 17, 8), now), DueBucket.today);
      expect(dueBucket(DateTime(2026, 11, 18), now), DueBucket.upcoming);
    });
  });

  group('habit streaks', () {
    final today = DateTime(2026, 11, 17, 15);
    Set<String> keys(List<int> daysAgo) => {for (final d in daysAgo) dayKey(addDays(today, -d))};

    test('streak counts through today', () => expect(currentStreak(keys([0, 1, 2]), today), 3));
    test('not done today yet keeps the streak from yesterday', () => expect(currentStreak(keys([1, 2]), today), 2));
    test('a gap breaks it', () => expect(currentStreak(keys([0, 2, 3]), today), 1));
    test('nothing recent', () => expect(currentStreak(keys([3, 4]), today), 0));
    test('best streak finds the longest run', () => expect(bestStreak(keys([0, 1, 5, 6, 7, 8, 20])), 4));
    test('best streak of nothing', () => expect(bestStreak(<String>{}), 0));
  });

  group('checklists and milestones', () {
    test('checklist round-trips and drops blank items', () {
      final raw = encodeChecklist(const [CheckItem('Milk'), CheckItem('  '), CheckItem('Eggs', done: true)]);
      expect(decodeChecklist(raw), const [CheckItem('Milk'), CheckItem('Eggs', done: true)]);
      expect(encodeChecklist(const []), '');
      expect(decodeChecklist('not json'), isEmpty);
    });

    test('milestones keep done state and escape the separator', () {
      final raw = encodeMilestones(const [CheckItem('Plan | book'), CheckItem('Go', done: true)]);
      expect(decodeMilestones(raw), const [CheckItem('Plan / book'), CheckItem('Go', done: true)]);
      // 1.x stored plain names.
      expect(decodeMilestones('A|B'), const [CheckItem('A'), CheckItem('B')]);
    });

    test('goal progress follows milestones, else the manual value', () {
      expect(goalProgress(milestones: '[x] A|B', manual: 0.9, completed: false), 0.5);
      expect(goalProgress(milestones: '', manual: 0.3, completed: false), 0.3);
      expect(goalProgress(milestones: 'A', manual: 0, completed: true), 1);
    });

    test('amount parsing', () {
      expect(parseAmount('12.50'), 12.5);
      expect(parseAmount('1,250'), 1250);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('-4'), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('3.456'), 3.46);
    });
  });

  group('assistant', () {
    final now = DateTime(2026, 11, 17, 9);
    String money(double v) => 'USD ${v.toStringAsFixed(2)}';

    test('routes questions to topics', () {
      expect(Assistant.topicFor('What is overdue?'), AssistantTopic.overdue);
      expect(Assistant.topicFor('how much did I spend'), AssistantTopic.spending);
      expect(Assistant.topicFor('plan my day'), AssistantTopic.today);
      expect(Assistant.topicFor('habit streaks'), AssistantTopic.habits);
      expect(Assistant.topicFor('translate this to French'), AssistantTopic.help);
    });

    test('plan puts overdue and urgent work first', () {
      final a = Assistant(
        AssistantData(tasks: [
          task('Water plants', due: DateTime(2026, 11, 17), priority: 0),
          task('Ship report', due: DateTime(2026, 11, 17, 14), priority: 3),
          task('Call bank', due: DateTime(2026, 11, 15)),
          task('Done thing', due: DateTime(2026, 11, 17), done: true),
        ]),
        money: money,
        now: now,
      );
      final plan = a.answerTopic(AssistantTopic.today);
      expect(plan, contains('Start with: Call bank'));
      expect(plan, contains('Ship report'));
      expect(plan, isNot(contains('Done thing')));
      expect(a.answerTopic(AssistantTopic.overdue), contains('Call bank: 2 days late'));
    });

    test('spending summary totals the month and flags budgets', () {
      ExpenseRow e(String d, double amt, String cat, DateTime date, {bool income = false}) => ExpenseRow(
            id: d,
            userId: kLocalUserId,
            description: d,
            amount: amt,
            category: cat,
            date: date,
            isIncome: income,
            tags: '',
            createdAt: date,
          );
      final a = Assistant(
        AssistantData(
          expenses: [
            e('Lunch', 12.5, 'Food', DateTime(2026, 11, 3)),
            e('Dinner', 40, 'Food', DateTime(2026, 11, 10)),
            e('Bus', 5, 'Transport', DateTime(2026, 11, 11)),
            e('Pay', 1000, 'Salary', DateTime(2026, 11, 1), income: true),
            e('Old', 99, 'Food', DateTime(2026, 9, 1)),
          ],
          budgets: [
            BudgetRow(id: 'b', userId: kLocalUserId, category: 'Food', limitAmount: 50, spentAmount: 0, month: DateTime(2026, 10)),
          ],
        ),
        money: money,
        now: now,
      );
      final s = a.answerTopic(AssistantTopic.spending);
      expect(s, contains('spent USD 57.50'));
      expect(s, contains('earned USD 1000.00'));
      expect(s, contains('Food is over budget by USD 2.50'));
      expect(s, contains('Biggest expense: Dinner'));
    });

    test('empty data gives friendly answers', () {
      final a = Assistant(const AssistantData(), money: money, now: now);
      for (final t in AssistantTopic.values) {
        expect(a.answerTopic(t), isNotEmpty);
      }
    });
  });
}
