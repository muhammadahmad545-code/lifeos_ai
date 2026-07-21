import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../domain/journal_entry.dart';

const List<String> _moods = <String>['😄', '🙂', '😐', '😔', '😢', '😡', '😴', '🤩'];

class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});

  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _delete(JournalEntry entry) async {
    try {
      await ref.read(journalRepositoryProvider).deleteEntry(entry.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openForm({JournalEntry? entry}) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final JournalEntry? result = await showModalBottomSheet<JournalEntry>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _JournalFormSheet(initial: entry),
    );
    if (result == null) {
      return;
    }
    try {
      if (entry == null) {
        await ref.read(journalRepositoryProvider).createEntry(userId, result);
      } else {
        await ref.read(journalRepositoryProvider).updateEntry(result);
      }
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<JournalEntry>> entriesAsync = ref.watch(watchJournalEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: entriesAsync.when(
        data: (List<JournalEntry> entries) {
          final String q = _query.trim().toLowerCase();
          final List<JournalEntry> filtered = q.isEmpty
              ? entries
              : entries
                  .where(
                    (JournalEntry e) =>
                        e.title.toLowerCase().contains(q) ||
                        e.content.toLowerCase().contains(q) ||
                        (e.mood?.toLowerCase().contains(q) ?? false),
                  )
                  .toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (String v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search journal...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyStateView(title: 'No entries yet', message: 'Tap the + button to reflect on your day.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                        itemCount: filtered.length,
                        itemBuilder: (BuildContext context, int index) {
                          final JournalEntry entry = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () => _openForm(entry: entry),
                              leading: CircleAvatar(child: Text(entry.mood ?? '📝', style: const TextStyle(fontSize: 18))),
                              title: Text(entry.title.isEmpty ? '(untitled)' : entry.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(entry.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  if (entry.createdAt != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(DateFormat.yMMMd().add_jm().format(entry.createdAt!), style: Theme.of(context).textTheme.bodySmall),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(entry),
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

class _JournalFormSheet extends StatefulWidget {
  const _JournalFormSheet({this.initial});

  final JournalEntry? initial;

  @override
  State<_JournalFormSheet> createState() => _JournalFormSheetState();
}

class _JournalFormSheetState extends State<_JournalFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _mood;

  @override
  void initState() {
    super.initState();
    final JournalEntry? entry = widget.initial;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _contentController = TextEditingController(text: entry?.content ?? '');
    _mood = entry?.mood ?? _moods.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty && _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write something first.')));
      return;
    }
    final JournalEntry result = (widget.initial ?? const JournalEntry(id: '', title: '', content: '')).copyWith(
      title: _titleController.text.trim().isEmpty ? DateFormat.yMMMd().format(DateTime.now()) : _titleController.text.trim(),
      content: _contentController.text.trim(),
      mood: _mood,
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
            Text(isEditing ? 'Edit entry' : 'New entry', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('How are you feeling?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _moods
                  .map(
                    (String m) => ChoiceChip(
                      label: Text(m, style: const TextStyle(fontSize: 18)),
                      selected: _mood == m,
                      onSelected: (_) => setState(() => _mood = m),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title (optional)')),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              autofocus: !isEditing,
              decoration: const InputDecoration(labelText: 'What happened today?', alignLabelWithHint: true),
              maxLines: 6,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(isEditing ? 'Save changes' : 'Save entry')),
          ],
        ),
      ),
    );
  }
}
