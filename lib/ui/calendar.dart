import 'package:basalt/basalt.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/dates.dart';
import '../providers.dart';
import 'common.dart';
import 'tasks.dart';

/// Events that touch [day] (multi-day events show on each day), sorted by start.
List<CalendarEventRow> eventsOn(List<CalendarEventRow> events, DateTime day) {
  final start = dateOnly(day);
  final end = addDays(start, 1);
  return events.where((e) => e.startTime.isBefore(end) && !e.endTime.isBefore(start)).toList()
    ..sort((a, b) {
      if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
      return a.startTime.compareTo(b.startTime);
    });
}

String eventTime(CalendarEventRow e) =>
    e.isAllDay ? 'All day' : '${fmtTime(e.startTime)} – ${fmtTime(e.endTime)}';

class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event});

  final CalendarEventRow event;

  @override
  Widget build(BuildContext context) {
    final loc = event.location?.trim() ?? '';
    return BListRow(
      icon: event.isAllDay ? Icons.wb_sunny_outlined : Icons.event_rounded,
      title: event.title,
      subtitle: [eventTime(event), if (loc.isNotEmpty) loc].join(' · '),
      onTap: () => push(context, EventEditor(event: event)),
    );
  }
}

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _month = monthStart(DateTime.now());
  DateTime _selected = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final events = ref.watch(eventsProvider).list;
    final tasks = ref.watch(tasksProvider).list.where((t) => t.parentId == null && t.dueDate != null).toList();
    final today = dateOnly(DateTime.now());

    // Which days in the visible grid have something on them.
    final first = _month;
    final lead = (first.weekday - DateTime.monday) % 7;
    final gridStart = addDays(first, -lead);
    final busy = <String>{};
    for (var i = 0; i < 42; i++) {
      final d = addDays(gridStart, i);
      if (eventsOn(events, d).isNotEmpty || tasks.any((t) => !t.isCompleted && sameDay(t.dueDate!, d))) busy.add(dayKey(d));
    }

    final dayEvents = eventsOn(events, _selected);
    final dayTasks = tasks.where((t) => sameDay(t.dueDate!, _selected)).toList()
      ..sort((a, b) => a.isCompleted == b.isCompleted ? a.dueDate!.compareTo(b.dueDate!) : (a.isCompleted ? 1 : -1));

    return BPage(
      title: 'Calendar',
      subtitle: DateFormat('MMMM y').format(_month),
      actions: [
        IconAction(icon: Icons.chevron_left_rounded, label: 'Previous month', onPressed: () => setState(() => _month = addMonths(_month, -1))),
        IconAction(icon: Icons.chevron_right_rounded, label: 'Next month', onPressed: () => setState(() => _month = addMonths(_month, 1))),
      ],
      floating: AddButton(label: 'New event', onPressed: () => push(context, EventEditor(day: _selected))),
      children: [
        BCard(
          padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.md, Gap.sm, Gap.sm),
          child: Column(
            children: [
              Row(
                children: [
                  for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(child: Center(child: Text(d, style: BasaltType.overline.copyWith(color: p.textFaint)))),
                ],
              ),
              const SizedBox(height: Gap.sm),
              for (var week = 0; week < 6; week++)
                Row(
                  children: [
                    for (var dow = 0; dow < 7; dow++)
                      Expanded(
                        child: _DayCell(
                          day: addDays(gridStart, week * 7 + dow),
                          inMonth: addDays(gridStart, week * 7 + dow).month == _month.month,
                          isToday: sameDay(addDays(gridStart, week * 7 + dow), today),
                          selected: sameDay(addDays(gridStart, week * 7 + dow), _selected),
                          busy: busy.contains(dayKey(addDays(gridStart, week * 7 + dow))),
                          onTap: () {
                            final d = addDays(gridStart, week * 7 + dow);
                            setState(() {
                              _selected = d;
                              if (d.month != _month.month || d.year != _month.year) _month = monthStart(d);
                            });
                          },
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        if (!sameDay(_selected, today) || _month != monthStart(today))
          Align(
            alignment: Alignment.centerRight,
            child: BButton(
              label: 'Today',
              variant: BButtonVariant.ghost,
              onPressed: () => setState(() {
                _selected = today;
                _month = monthStart(today);
              }),
            ),
          ),
        BSectionTitle(relativeDay(_selected) == 'Today' ? 'Today, ${fmtDate(_selected)}' : fmtDate(_selected)),
        if (dayEvents.isEmpty && dayTasks.isEmpty)
          BCard(
            child: Text('Nothing planned. Tap New event to add one.', style: BasaltType.body.copyWith(color: p.textMuted)),
          ),
        if (dayEvents.isNotEmpty) BGroup(children: [for (final e in dayEvents) EventRow(event: e)]),
        if (dayTasks.isNotEmpty) ...[
          const BSectionTitle('Tasks due'),
          BGroup(children: [for (final t in dayTasks) TaskTile(task: t)]),
        ],
        const SizedBox(height: 72),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final fg = selected ? p.onAccent : (isToday ? p.accent : (inMonth ? p.text : p.textFaint));
    return Semantics(
      button: true,
      selected: selected,
      label: DateFormat('EEEE, MMMM d').format(day),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: SizedBox(
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? p.accent : Colors.transparent,
                  border: isToday && !selected ? Border.all(color: p.accent) : null,
                ),
                child: Text(
                  '${day.day}',
                  style: BasaltType.label.copyWith(color: fg, fontWeight: isToday || selected ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(shape: BoxShape.circle, color: busy ? p.accent : Colors.transparent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventEditor extends ConsumerStatefulWidget {
  const EventEditor({super.key, this.event, this.day});

  final CalendarEventRow? event;
  final DateTime? day;

  @override
  ConsumerState<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<EventEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.event?.title ?? '');
  late final TextEditingController _location = TextEditingController(text: widget.event?.location ?? '');
  late final TextEditingController _notes = TextEditingController(text: widget.event?.description ?? '');
  late DateTime _date;
  late DateTime _endDate;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _allDay;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _date = dateOnly(e.startTime);
      _endDate = dateOnly(e.endTime);
      _start = TimeOfDay.fromDateTime(e.startTime);
      _end = TimeOfDay.fromDateTime(e.endTime);
      _allDay = e.isAllDay;
    } else {
      _date = dateOnly(widget.day ?? DateTime.now());
      _endDate = _date;
      final now = DateTime.now();
      final h = (now.hour + 1).clamp(0, 22);
      _start = TimeOfDay(hour: h, minute: 0);
      _end = TimeOfDay(hour: h + 1, minute: 0);
      _allDay = false;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _at(DateTime d, TimeOfDay t) => DateTime(d.year, d.month, d.day, t.hour, t.minute);

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      BToast.show(context, 'Give the event a title');
      return;
    }
    DateTime start;
    DateTime end;
    if (_allDay) {
      start = _date;
      end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59);
      if (end.isBefore(start)) end = DateTime(_date.year, _date.month, _date.day, 23, 59);
    } else {
      start = _at(_date, _start);
      end = _at(_endDate, _end);
      if (!end.isAfter(start)) {
        BToast.show(context, 'The event must end after it starts');
        return;
      }
    }
    final loc = _location.text.trim();
    final notes = _notes.text.trim();
    await ref.read(repoProvider).saveEvent(
          CalendarEventsCompanion(
            title: Value(title),
            startTime: Value(start),
            endTime: Value(end),
            isAllDay: Value(_allDay),
            location: Value(loc.isEmpty ? null : loc),
            description: Value(notes.isEmpty ? null : notes),
          ),
          id: widget.event?.id,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await bConfirm(context, title: 'Delete event?', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    await ref.read(repoProvider).deleteEvent(widget.event!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      title: widget.event == null ? 'New event' : 'Edit event',
      onSave: _save,
      actions: [
        if (widget.event != null) IconAction(icon: Icons.delete_outline_rounded, label: 'Delete event', onPressed: _delete),
      ],
      children: [
        TextField(
          controller: _title,
          autofocus: widget.event == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: Gap.md),
        BGroup(
          children: [
            SwitchRow(
              icon: Icons.wb_sunny_outlined,
              title: 'All day',
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
            ),
          ],
        ),
        const FieldLabel('Starts'),
        Row(
          children: [
            Expanded(
              child: PickerField(
                icon: Icons.event_rounded,
                label: fmtDate(_date),
                onTap: () async {
                  final d = await pickDate(context, _date);
                  if (d == null) return;
                  setState(() {
                    final span = daysBetween(_date, _endDate);
                    _date = d;
                    _endDate = addDays(d, span < 0 ? 0 : span);
                  });
                },
              ),
            ),
            if (!_allDay) ...[
              const SizedBox(width: Gap.sm),
              Expanded(
                child: PickerField(
                  icon: Icons.schedule_rounded,
                  label: _start.format(context),
                  onTap: () async {
                    final t = await pickTime(context, _start);
                    if (t == null) return;
                    setState(() {
                      final length = _at(_endDate, _end).difference(_at(_date, _start));
                      _start = t;
                      final newEnd = _at(_date, t).add(length.isNegative ? const Duration(hours: 1) : length);
                      _endDate = dateOnly(newEnd);
                      _end = TimeOfDay.fromDateTime(newEnd);
                    });
                  },
                ),
              ),
            ],
          ],
        ),
        const FieldLabel('Ends'),
        Row(
          children: [
            Expanded(
              child: PickerField(
                icon: Icons.event_rounded,
                label: fmtDate(_endDate),
                onTap: () async {
                  final d = await pickDate(context, _endDate);
                  if (d != null) setState(() => _endDate = d.isBefore(_date) ? _date : d);
                },
              ),
            ),
            if (!_allDay) ...[
              const SizedBox(width: Gap.sm),
              Expanded(
                child: PickerField(
                  icon: Icons.schedule_rounded,
                  label: _end.format(context),
                  onTap: () async {
                    final t = await pickTime(context, _end);
                    if (t != null) setState(() => _end = t);
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: _location,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Location (optional)', prefixIcon: Icon(Icons.place_outlined)),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
      ],
    );
  }
}
