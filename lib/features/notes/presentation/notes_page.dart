import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../domain/note.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _showArchived = false;

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

  Future<void> _togglePin(Note note) async {
    try {
      await ref.read(noteRepositoryProvider).togglePin(note.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleFavorite(Note note) async {
    try {
      await ref.read(noteRepositoryProvider).toggleFavorite(note.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleArchive(Note note) async {
    try {
      await ref.read(noteRepositoryProvider).archiveNote(note.id, archived: !note.isArchived);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(note.isArchived ? 'Note restored' : 'Note archived')),
        );
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(Note note) async {
    try {
      await ref.read(noteRepositoryProvider).deleteNote(note.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openEditor({Note? note}) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final Note? result = await showDialog<Note>(
      context: context,
      builder: (BuildContext context) => _NoteEditorDialog(initial: note),
    );
    if (result == null) {
      return;
    }
    try {
      if (note == null) {
        await ref.read(noteRepositoryProvider).createNote(userId, result);
      } else {
        await ref.read(noteRepositoryProvider).updateNote(result);
      }
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Note>> notesAsync = ref.watch(watchNotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: <Widget>[
          IconButton(
            icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
            tooltip: 'Show archived',
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: notesAsync.when(
        data: (List<Note> notes) {
          final String q = _query.trim().toLowerCase();
          final List<Note> filtered = notes.where((Note n) {
            if (n.isArchived != _showArchived) {
              return false;
            }
            if (q.isEmpty) {
              return true;
            }
            return n.title.toLowerCase().contains(q) ||
                n.content.toLowerCase().contains(q) ||
                n.tags.any((String t) => t.toLowerCase().contains(q));
          }).toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (String v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyStateView(
                        title: _showArchived ? 'No archived notes' : 'No notes yet',
                        message: _showArchived
                            ? 'Notes you archive will show up here.'
                            : 'Tap the + button to write your first note.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                        itemCount: filtered.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Note note = filtered[index];
                          final Color? color = note.color != null ? Color(int.tryParse(note.color!) ?? 0xFFFFFFFF) : null;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            color: color,
                            child: ListTile(
                              onTap: () => _openEditor(note: note),
                              title: Row(
                                children: <Widget>[
                                  if (note.isPinned) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, size: 14)),
                                  Expanded(
                                    child: Text(
                                      note.title.isEmpty ? '(untitled)' : note.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  if (note.tags.isNotEmpty || note.folder != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Wrap(
                                        spacing: 6,
                                        children: <Widget>[
                                          if (note.folder != null) Chip(label: Text(note.folder!), visualDensity: VisualDensity.compact),
                                          for (final String tag in note.tags) Chip(label: Text(tag), visualDensity: VisualDensity.compact),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: note.tags.isNotEmpty || note.folder != null,
                              trailing: PopupMenuButton<String>(
                                onSelected: (String value) {
                                  switch (value) {
                                    case 'pin':
                                      _togglePin(note);
                                    case 'favorite':
                                      _toggleFavorite(note);
                                    case 'archive':
                                      _toggleArchive(note);
                                    case 'delete':
                                      _delete(note);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(value: 'pin', child: Text(note.isPinned ? 'Unpin' : 'Pin')),
                                  PopupMenuItem<String>(
                                    value: 'favorite',
                                    child: Text(note.isFavorite ? 'Unfavorite' : 'Favorite'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'archive',
                                    child: Text(note.isArchived ? 'Unarchive' : 'Archive'),
                                  ),
                                  const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                                ],
                                icon: Icon(note.isFavorite ? Icons.favorite : Icons.more_vert, color: note.isFavorite ? Colors.red : null),
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
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({this.initial});

  final Note? initial;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagsController;
  late final TextEditingController _folderController;

  @override
  void initState() {
    super.initState();
    final Note? note = widget.initial;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _tagsController = TextEditingController(text: note?.tags.join(', ') ?? '');
    _folderController = TextEditingController(text: note?.folder ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty && _contentController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final List<String> tags = _tagsController.text
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    final Note result = (widget.initial ?? const Note(id: '', title: '', content: '')).copyWith(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      tags: tags,
      folder: _folderController.text.trim().isEmpty ? null : _folderController.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initial != null;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(isEditing ? 'Edit note' : 'New note', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                autofocus: !isEditing,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(labelText: 'Content', alignLabelWithHint: true),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _folderController,
                      decoration: const InputDecoration(labelText: 'Folder'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _tagsController,
                      decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _submit, child: Text(isEditing ? 'Save' : 'Create')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
