import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/premium_card.dart';
import '../domain/health_log.dart';

const double _dailyWaterGoalMl = 2000;

class _TrackerSpec {
  const _TrackerSpec({
    required this.type,
    required this.label,
    required this.icon,
    required this.unit,
    required this.valueLabel,
  });

  final HealthLogType type;
  final String label;
  final IconData icon;
  final String unit;
  final String valueLabel;
}

const List<_TrackerSpec> _trackers = <_TrackerSpec>[
  _TrackerSpec(type: HealthLogType.water, label: 'Water', icon: Icons.local_drink_outlined, unit: 'ml', valueLabel: 'Amount (ml)'),
  _TrackerSpec(type: HealthLogType.sleep, label: 'Sleep', icon: Icons.bedtime_outlined, unit: 'hrs', valueLabel: 'Hours slept'),
  _TrackerSpec(type: HealthLogType.weight, label: 'Weight', icon: Icons.monitor_weight_outlined, unit: 'kg', valueLabel: 'Weight (kg)'),
  _TrackerSpec(type: HealthLogType.workout, label: 'Workout', icon: Icons.fitness_center_outlined, unit: 'min', valueLabel: 'Duration (min)'),
  _TrackerSpec(type: HealthLogType.medicine, label: 'Medicine', icon: Icons.medication_outlined, unit: 'dose', valueLabel: 'Dose'),
];

class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _trackers.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _quickAddWater(double ml) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    try {
      await ref.read(healthRepositoryProvider).addLog(
            userId,
            HealthLog(id: '', type: HealthLogType.water, value: ml, unit: 'ml', loggedAt: DateTime.now()),
          );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openAddDialog(_TrackerSpec spec) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final HealthLog? result = await showDialog<HealthLog>(
      context: context,
      builder: (BuildContext context) => _LogFormDialog(spec: spec),
    );
    if (result == null) {
      return;
    }
    try {
      await ref.read(healthRepositoryProvider).addLog(userId, result);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(String logId) async {
    try {
      await ref.read(healthRepositoryProvider).deleteLog(logId);
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health & Wellness'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _trackers.map((_TrackerSpec s) => Tab(icon: Icon(s.icon), text: s.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _trackers.map((_TrackerSpec spec) => _TrackerTab(spec: spec, onDelete: _delete)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddDialog(_trackers[_tabController.index]),
        tooltip: 'Log entry',
        child: const Icon(Icons.add),
      ),
      persistentFooterButtons: _tabController.index == 0
          ? <Widget>[
              TextButton.icon(onPressed: () => _quickAddWater(100), icon: const Icon(Icons.add), label: const Text('100 ml')),
              TextButton.icon(onPressed: () => _quickAddWater(250), icon: const Icon(Icons.add), label: const Text('250 ml')),
              TextButton.icon(onPressed: () => _quickAddWater(500), icon: const Icon(Icons.add), label: const Text('500 ml')),
            ]
          : null,
    );
  }
}

class _TrackerTab extends ConsumerWidget {
  const _TrackerTab({required this.spec, required this.onDelete});

  final _TrackerSpec spec;
  final void Function(String logId) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<HealthLog>> logsAsync = ref.watch(healthLogsProvider(spec.type));

    return logsAsync.when(
      data: (List<HealthLog> logs) {
        final DateTime now = DateTime.now();
        final List<HealthLog> today = logs.where((HealthLog l) {
          final DateTime d = l.loggedAt;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();
        final double todayTotal = today.fold<double>(0, (double sum, HealthLog l) => sum + l.value);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            PremiumCard(
              child: Row(
                children: <Widget>[
                  Icon(spec.icon, size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Today', style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          spec.type == HealthLogType.water
                              ? '${todayTotal.round()} / ${_dailyWaterGoalMl.round()} ${spec.unit}'
                              : spec.type == HealthLogType.weight
                                  ? (logs.isEmpty ? '—' : '${logs.first.value.toStringAsFixed(1)} ${spec.unit}')
                                  : '${todayTotal.toStringAsFixed(spec.type == HealthLogType.sleep ? 1 : 0)} ${spec.unit}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (spec.type == HealthLogType.water) ...<Widget>[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (todayTotal / _dailyWaterGoalMl).clamp(0, 1),
                  minHeight: 10,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (logs.isEmpty)
              EmptyStateView(
                title: 'No ${spec.label.toLowerCase()} logs yet',
                message: 'Tap the + button to add your first entry.',
              )
            else
              ...logs.map(
                (HealthLog log) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(spec.icon, size: 18)),
                    title: Text('${log.value.toStringAsFixed(log.value % 1 == 0 ? 0 : 1)} ${log.unit}'),
                    subtitle: Text(
                      log.note != null && log.note!.isNotEmpty
                          ? '${DateFormat.MMMd().add_jm().format(log.loggedAt)} · ${log.note}'
                          : DateFormat.MMMd().add_jm().format(log.loggedAt),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDelete(log.id),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const LoadingView(),
      error: (Object error, StackTrace stack) => ErrorView(error: error),
    );
  }
}

class _LogFormDialog extends StatefulWidget {
  const _LogFormDialog({required this.spec});

  final _TrackerSpec spec;

  @override
  State<_LogFormDialog> createState() => _LogFormDialogState();
}

class _LogFormDialogState extends State<_LogFormDialog> {
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final double? value = double.tryParse(_valueController.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid number.')));
      return;
    }
    Navigator.of(context).pop(
      HealthLog(
        id: '',
        type: widget.spec.type,
        value: value,
        unit: widget.spec.unit,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        loggedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Log ${widget.spec.label.toLowerCase()}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _valueController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: widget.spec.valueLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
