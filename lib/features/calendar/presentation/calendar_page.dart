import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../domain/calendar_event.dart';

enum _CalendarView { month, week, day, agenda }

const List<String> _blockColors = <String>['2563EB', '0D9488', 'F59E0B', 'EF4444', '8B5CF6'];

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  _CalendarView _view = _CalendarView.month;

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _delete(CalendarEvent event) async {
    try {
      await ref.read(calendarRepositoryProvider).deleteEvent(event.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openForm({CalendarEvent? event, DateTime? startHint, bool asTimeBlock = false}) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final CalendarEvent? result = await showModalBottomSheet<CalendarEvent>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _EventFormSheet(
        initial: event,
        day: _selectedDay,
        startHint: startHint,
        asTimeBlock: asTimeBlock || (event?.isTimeBlock ?? false),
      ),
    );
    if (result == null) {
      return;
    }
    try {
      if (event == null) {
        await ref.read(calendarRepositoryProvider).createEvent(userId, result);
      } else {
        await ref.read(calendarRepositoryProvider).updateEvent(result);
      }
    } catch (error) {
      _showError(error);
    }
  }

  List<DateTime> _daysInMonthGrid(DateTime month) {
    final DateTime first = DateTime(month.year, month.month, 1);
    final int startWeekday = first.weekday;
    final DateTime gridStart = first.subtract(Duration(days: startWeekday - 1));
    return List<DateTime>.generate(42, (int i) => DateTime(gridStart.year, gridStart.month, gridStart.day + i));
  }

  List<DateTime> _weekDays() {
    final DateTime startOfWeek = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    return List<DateTime>.generate(7, (int i) => startOfWeek.add(Duration(days: i)));
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Color _eventColor(CalendarEvent event, BuildContext context) {
    if (event.color != null) {
      return Color(int.parse('FF${event.color}', radix: 16));
    }
    return event.isTimeBlock ? const Color(0xFF0D9488) : Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CalendarEvent>> eventsAsync = ref.watch(watchCalendarEventsProvider);
    final DateTime today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMM().format(_visibleMonth)),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
          ),
          IconButton(
            icon: const Icon(Icons.today_outlined),
            onPressed: () => setState(() {
              _selectedDay = DateTime(today.year, today.month, today.day);
              _visibleMonth = DateTime(today.year, today.month);
            }),
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (List<CalendarEvent> events) {
          final List<CalendarEvent> dayEvents = events.where((CalendarEvent e) => _sameDay(e.startTime, _selectedDay)).toList()
            ..sort((CalendarEvent a, CalendarEvent b) => a.startTime.compareTo(b.startTime));
          final List<CalendarEvent> agenda = List<CalendarEvent>.from(events)
            ..sort((CalendarEvent a, CalendarEvent b) => a.startTime.compareTo(b.startTime));

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_CalendarView>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<_CalendarView>>[
                      ButtonSegment<_CalendarView>(value: _CalendarView.month, label: Text('Month')),
                      ButtonSegment<_CalendarView>(value: _CalendarView.week, label: Text('Week')),
                      ButtonSegment<_CalendarView>(value: _CalendarView.day, label: Text('Day')),
                      ButtonSegment<_CalendarView>(value: _CalendarView.agenda, label: Text('Agenda')),
                    ],
                    selected: <_CalendarView>{_view},
                    onSelectionChanged: (Set<_CalendarView> value) => setState(() => _view = value.first),
                  ),
                ),
              ),
              if (_view == _CalendarView.month) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map(
                          (String d) => Expanded(
                            child: Center(child: Text(d, style: Theme.of(context).textTheme.labelSmall)),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: 42,
                    itemBuilder: (BuildContext context, int index) {
                      final DateTime day = _daysInMonthGrid(_visibleMonth)[index];
                      final bool inMonth = day.month == _visibleMonth.month;
                      final bool selected = _sameDay(day, _selectedDay);
                      final bool isToday = _sameDay(day, today);
                      final bool hasEvents = events.any((CalendarEvent e) => _sameDay(e.startTime, day));
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() {
                          _selectedDay = day;
                          if (day.month != _visibleMonth.month) {
                            _visibleMonth = DateTime(day.year, day.month);
                          }
                        }),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : isToday
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : inMonth
                                          ? null
                                          : Theme.of(context).disabledColor,
                                ),
                              ),
                              if (hasEvents)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.only(top: 3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected ? Colors.white : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (_view == _CalendarView.week)
                SizedBox(
                  height: 84,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: _weekDays().map((DateTime day) {
                      final bool selected = _sameDay(day, _selectedDay);
                      final bool isToday = _sameDay(day, today);
                      final bool hasEvents = events.any((CalendarEvent e) => _sameDay(e.startTime, day));
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDay = day),
                        child: Container(
                          width: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: isToday && !selected ? Border.all(color: Theme.of(context).colorScheme.primary) : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(DateFormat.E().format(day), style: TextStyle(color: selected ? Colors.white70 : null, fontSize: 11)),
                              Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : null)),
                              if (hasEvents)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected ? Colors.white : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (_view == _CalendarView.day)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          DateFormat.EEEE().add_MMMd().format(_selectedDay),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openForm(asTimeBlock: true),
                        icon: const Icon(Icons.view_timeline_outlined),
                        label: const Text('Block'),
                      ),
                    ],
                  ),
                ),
              if (_view != _CalendarView.agenda && _view != _CalendarView.day) const Divider(height: 1),
              Expanded(
                flex: _view == _CalendarView.month ? 2 : 5,
                child: switch (_view) {
                  _CalendarView.agenda => agenda.isEmpty
                      ? const EmptyStateView(title: 'No events', message: 'Tap + to add your first event.')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                          itemCount: agenda.length,
                          itemBuilder: (BuildContext context, int index) {
                            final CalendarEvent event = agenda[index];
                            return _EventTile(
                              event: event,
                              color: _eventColor(event, context),
                              onTap: () => _openForm(event: event),
                              onDelete: () => _delete(event),
                            );
                          },
                        ),
                  _CalendarView.day => _DayTimeGrid(
                      day: _selectedDay,
                      events: dayEvents,
                      colorFor: (CalendarEvent e) => _eventColor(e, context),
                      onTapEvent: (CalendarEvent e) => _openForm(event: e),
                      onTapHour: (DateTime hour) => _openForm(startHint: hour, asTimeBlock: true),
                    ),
                  _ => dayEvents.isEmpty
                      ? EmptyStateView(
                          title: 'No events on ${DateFormat.MMMd().format(_selectedDay)}',
                          message: 'Tap + to schedule something, or open Day view for time blocking.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                          itemCount: dayEvents.length,
                          itemBuilder: (BuildContext context, int index) {
                            final CalendarEvent event = dayEvents[index];
                            return _EventTile(
                              event: event,
                              color: _eventColor(event, context),
                              onTap: () => _openForm(event: event),
                              onDelete: () => _delete(event),
                            );
                          },
                        ),
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DayTimeGrid extends StatelessWidget {
  const _DayTimeGrid({
    required this.day,
    required this.events,
    required this.colorFor,
    required this.onTapEvent,
    required this.onTapHour,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final Color Function(CalendarEvent) colorFor;
  final void Function(CalendarEvent) onTapEvent;
  final void Function(DateTime) onTapHour;

  static const int _startHour = 6;
  static const int _endHour = 22;
  static const double _hourHeight = 64;

  @override
  Widget build(BuildContext context) {
    final int hours = _endHour - _startHour;
    final List<CalendarEvent> timed = events.where((CalendarEvent e) => !e.isAllDay).toList();
    final List<CalendarEvent> allDay = events.where((CalendarEvent e) => e.isAllDay).toList();

    return Column(
      children: <Widget>[
        if (allDay.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: allDay
                  .map(
                    (CalendarEvent e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(e.title),
                        onPressed: () => onTapEvent(e),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 12, 88),
            child: SizedBox(
              height: hours * _hourHeight,
              child: Stack(
                children: <Widget>[
                  Column(
                    children: List<Widget>.generate(hours, (int i) {
                      final int hour = _startHour + i;
                      final DateTime slot = DateTime(day.year, day.month, day.day, hour);
                      return InkWell(
                        onTap: () => onTapHour(slot),
                        child: Container(
                          height: _hourHeight,
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
                          ),
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 52,
                                child: Text(
                                  DateFormat.j().format(slot),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                              const Expanded(child: SizedBox.shrink()),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  ...timed.map((CalendarEvent event) {
                    final DateTime start = event.startTime;
                    final DateTime end = event.endTime.isAfter(start) ? event.endTime : start.add(const Duration(minutes: 30));
                    final double top = ((start.hour + start.minute / 60) - _startHour) * _hourHeight;
                    final double height = ((end.difference(start).inMinutes) / 60) * _hourHeight;
                    final Color color = colorFor(event);
                    return Positioned(
                      top: top.clamp(0, hours * _hourHeight - 24),
                      left: 56,
                      right: 0,
                      height: height.clamp(28, hours * _hourHeight),
                      child: Material(
                        color: color.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onTapEvent(event),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text(
                              '${event.isTimeBlock ? '⏱ ' : ''}${event.title}\n${DateFormat.jm().format(start)} – ${DateFormat.jm().format(end)}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12, height: 1.2),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.color, required this.onTap, required this.onDelete});

  final CalendarEvent event;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(
            event.isTimeBlock
                ? Icons.view_timeline
                : event.isAllDay
                    ? Icons.event_note
                    : Icons.schedule,
            color: color,
          ),
        ),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          event.isAllDay
              ? 'All day · ${DateFormat.MMMd().format(event.startTime)}${event.location != null ? ' · ${event.location}' : ''}'
              : '${event.isTimeBlock ? 'Time block · ' : ''}${DateFormat.MMMd().add_jm().format(event.startTime)} – ${DateFormat.jm().format(event.endTime)}'
                  '${event.location != null ? ' · ${event.location}' : ''}',
        ),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      ),
    );
  }
}

class _EventFormSheet extends StatefulWidget {
  const _EventFormSheet({
    this.initial,
    required this.day,
    this.startHint,
    this.asTimeBlock = false,
  });

  final CalendarEvent? initial;
  final DateTime day;
  final DateTime? startHint;
  final bool asTimeBlock;

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late DateTime _start;
  late DateTime _end;
  late bool _isAllDay;
  late bool _isTimeBlock;
  late String _color;

  @override
  void initState() {
    super.initState();
    final CalendarEvent? event = widget.initial;
    _titleController = TextEditingController(text: event?.title ?? (widget.asTimeBlock ? 'Focus block' : ''));
    _locationController = TextEditingController(text: event?.location ?? '');
    _descriptionController = TextEditingController(text: event?.description ?? '');
    _start = event?.startTime ??
        widget.startHint ??
        DateTime(widget.day.year, widget.day.month, widget.day.day, 9);
    _end = event?.endTime ?? _start.add(const Duration(hours: 1));
    _isAllDay = event?.isAllDay ?? false;
    _isTimeBlock = event?.isTimeBlock ?? widget.asTimeBlock;
    _color = event?.color ?? _blockColors.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final DateTime initial = isStart ? _start : _end;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) {
      return;
    }
    TimeOfDay time = TimeOfDay.fromDateTime(initial);
    if (!_isAllDay) {
      final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: time);
      if (pickedTime == null) {
        return;
      }
      time = pickedTime;
    }
    final DateTime combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = combined;
        if (_end.isBefore(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = combined;
      }
    });
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }
    if (!_isAllDay && !_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End time must be after start time.')));
      return;
    }
    final CalendarEvent result = (widget.initial ?? CalendarEvent(id: '', title: '', startTime: _start, endTime: _end)).copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      startTime: _start,
      endTime: _end,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      isAllDay: _isTimeBlock ? false : _isAllDay,
      isTimeBlock: _isTimeBlock,
      color: _color,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initial != null;
    final DateFormat fmt = DateFormat.MMMd().add_jm();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isEditing ? 'Edit event' : (_isTimeBlock ? 'New time block' : 'New event'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(controller: _titleController, autofocus: !isEditing, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time block'),
              subtitle: const Text('Mark this as focused work time'),
              value: _isTimeBlock,
              onChanged: (bool value) => setState(() {
                _isTimeBlock = value;
                if (value) {
                  _isAllDay = false;
                }
              }),
            ),
            if (!_isTimeBlock)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All day'),
                value: _isAllDay,
                onChanged: (bool value) => setState(() => _isAllDay = value),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow),
              title: const Text('Starts'),
              subtitle: Text(_isAllDay ? DateFormat.MMMd().format(_start) : fmt.format(_start)),
              onTap: () => _pickDateTime(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stop),
              title: const Text('Ends'),
              subtitle: Text(_isAllDay ? DateFormat.MMMd().format(_end) : fmt.format(_end)),
              onTap: () => _pickDateTime(isStart: false),
            ),
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _blockColors.map((String hex) {
                final Color color = Color(int.parse('FF$hex', radix: 16));
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: color,
                    child: _color == hex ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location (optional)')),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(isEditing ? 'Save changes' : 'Create')),
          ],
        ),
      ),
    );
  }
}
