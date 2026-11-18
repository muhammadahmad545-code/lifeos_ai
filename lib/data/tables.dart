import 'package:drift/drift.dart';

// Table and column names match the 1.x schema so existing databases upgrade in place.
// Every row still carries a userId; since 2.0 it is always [kLocalUserId].

@DataClassName('TaskRow')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  TextColumn get project => text().nullable()();
  TextColumn get labels => text().withDefault(const Constant(''))();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurrence => text().withDefault(const Constant('none'))();
  DateTimeColumn get reminderAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get color => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant(''))();
  TextColumn get folder => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  // JSON list of {"t": text, "d": done}. Added in schema 5.
  TextColumn get checklist => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CalendarEventRow')
class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  TextColumn get location => text().nullable()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  BoolColumn get isTimeBlock => boolean().withDefault(const Constant(false))();
  TextColumn get color => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('HabitRow')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get frequency => integer().withDefault(const Constant(0))();
  TextColumn get color => text().nullable()();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastCompletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One row per habit per day it was done. Day is a local `yyyy-MM-dd` key. Added in schema 5.
@DataClassName('HabitLogRow')
class HabitLogs extends Table {
  TextColumn get habitId => text()();
  TextColumn get day => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {habitId, day};
}

@DataClassName('JournalEntryRow')
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get mood => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  TextColumn get tags => text().withDefault(const Constant(''))();
  TextColumn get receiptPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get category => text()();
  RealColumn get limitAmount => real()();
  RealColumn get spentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get month => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GoalRow')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get targetDate => dateTime()();
  TextColumn get category => text().nullable()();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  TextColumn get milestones => text().withDefault(const Constant(''))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get visionImagePath => text().nullable()();
  TextColumn get visionColor => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FocusSessionRow')
class FocusSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  IntColumn get durationMinutes => integer()();
  IntColumn get completedMinutes => integer().withDefault(const Constant(0))();
  TextColumn get mode => text().withDefault(const Constant('pomodoro'))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
