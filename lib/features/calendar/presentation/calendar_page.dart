import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../domain/calendar_event.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _selectedDay = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _delete(CalendarEvent event) async {
    try {
      await ref.read(calendarRepositoryProvider).deleteEvent(event.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openForm({CalendarEvent? event}) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final CalendarEvent? result = await showModalBottomSheet<CalendarEvent>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _EventFormSheet(initial: event, day: _selectedDay),
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

  List<DateTime> _weekDays() {
    final DateTime startOfWeek = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    return List<DateTime>.generate(7, (int i) => startOfWeek.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CalendarEvent>> eventsAsync = ref.watch(watchCalendarEventsProvider);
    final DateTime today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMM().format(_selectedDay)),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.calendar_month_outlined), onPressed: _pickDate),
        ],
      ),
      body: eventsAsync.when(
        data: (List<CalendarEvent> events) {
          final List<CalendarEvent> dayEvents = events.where((CalendarEvent e) {
                final DateTime s = e.startTime;
                return s.year == _selectedDay.year && s.month == _selectedDay.month && s.day == _selectedDay.day;
              }).toList()
            ..sort((CalendarEvent a, CalendarEvent b) => a.startTime.compareTo(b.startTime));

          return Column(
            children: <Widget>[
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: _weekDays().map((DateTime day) {
                    final bool isSelected = day.year == _selectedDay.year && day.month == _selectedDay.month && day.day == _selectedDay.day;
                    final bool isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                    final bool hasEvents = events.any((CalendarEvent e) =>
                        e.startTime.year == day.year && e.startTime.month == day.month && e.startTime.day == day.day);
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDay = day),
                      child: Container(
                        width: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: isToday && !isSelected ? Border.all(color: Theme.of(context).colorScheme.primary) : null,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              DateFormat.E().format(day),
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (hasEvents)
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: dayEvents.isEmpty
                    ? const EmptyStateView(title: 'No events', message: 'Tap the + button to schedule something.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: dayEvents.length,
                        itemBuilder: (BuildContext context, int index) {
                          final CalendarEvent event = dayEvents[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () => _openForm(event: event),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(event.isAllDay ? Icons.event_note : Icons.schedule, color: Theme.of(context).colorScheme.onPrimaryContainer),
                              ),
                              title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                event.isAllDay
                                    ? 'All day${event.location != null ? ' · ${event.location}' : ''}'
                                    : '${DateFormat.jm().format(event.startTime)} – ${DateFormat.jm().format(event.endTime)}'
                                        '${event.location != null ? ' · ${event.location}' : ''}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(event),
                              ),
                            ),
                          );
                        },
                      ),
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

class _EventFormSheet extends StatefulWidget {
  const _EventFormSheet({this.initial, required this.day});

  final CalendarEvent? initial;
  final DateTime day;

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

  @override
  void initState() {
    super.initState();
    final CalendarEvent? event = widget.initial;
    _titleController = TextEditingController(text: event?.title ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');
    _descriptionController = TextEditingController(text: event?.description ?? '');
    _start = event?.startTime ?? DateTime(widget.day.year, widget.day.month, widget.day.day, 9);
    _end = event?.endTime ?? _start.add(const Duration(hours: 1));
    _isAllDay = event?.isAllDay ?? false;
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
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End time must be after start time.')));
      return;
    }
    final CalendarEvent result = (widget.initial ?? CalendarEvent(id: '', title: '', startTime: _start, endTime: _end)).copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      startTime: _start,
      endTime: _end,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      isAllDay: _isAllDay,
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
            Text(isEditing ? 'Edit event' : 'New event', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _titleController, autofocus: !isEditing, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            const SizedBox(height: 12),
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
            const SizedBox(height: 8),
            TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location (optional)')),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(isEditing ? 'Save changes' : 'Create event')),
          ],
        ),
      ),
    );
  }
}
