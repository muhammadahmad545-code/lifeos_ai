import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/note_pdf_exporter.dart';
import '../../../core/utils/media_path_helper.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../domain/note.dart';
import '../domain/note_version.dart';
import 'note_drawing_page.dart';

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

  Future<void> _exportPdf(Note note) async {
    try {
      await NotePdfExporter().shareNotePdf(note);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showHistory(Note note) async {
    final List<NoteVersion> versions = await ref.read(noteRepositoryProvider).getVersions(note.id);
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: versions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No previous versions yet. Edit and save this note to create history.'),
              )
            : ListView(
                shrinkWrap: true,
                children: <Widget>[
                  const ListTile(
                    title: Text('Version history'),
                    subtitle: Text('Restore an earlier snapshot'),
                  ),
                  ...versions.map(
                    (NoteVersion version) => ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(version.title.isEmpty ? '(Untitled)' : version.title),
                      subtitle: Text(
                        '${DateFormat.yMMMd().add_jm().format(version.createdAt)}\n'
                        '${version.content.isEmpty ? '(empty)' : version.content}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(noteRepositoryProvider).restoreVersion(note.id, version.id);
                            if (!mounted) {
                              return;
                            }
                            Navigator.of(this.context).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Version restored')),
                            );
                          } catch (error) {
                            _showError(error);
                          }
                        },
                        child: const Text('Restore'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _openEditor({Note? note}) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final Note? result = await showDialog<Note>(
      context: context,
      builder: (BuildContext context) => _NoteEditorDialog(
        initial: note,
        onOcrImage: (String path) => ref.read(ocrServiceProvider).extractText(path),
      ),
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
                                    case 'history':
                                      _showHistory(note);
                                    case 'pdf':
                                      _exportPdf(note);
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
                                  const PopupMenuItem<String>(value: 'history', child: Text('Version history')),
                                  const PopupMenuItem<String>(value: 'pdf', child: Text('Export PDF')),
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
  const _NoteEditorDialog({this.initial, required this.onOcrImage});

  final Note? initial;
  final Future<String> Function(String path) onOcrImage;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagsController;
  late final TextEditingController _folderController;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _preview = false;
  bool _recording = false;
  bool _ocrBusy = false;
  String? _playingPath;

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
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _appendLine(String line) {
    final String current = _contentController.text;
    final String next = current.isEmpty ? line : '$current\n$line';
    setState(() => _contentController.text = next);
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final String? path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null && path.isNotEmpty) {
        _appendLine('[voice]($path)');
      }
      return;
    }
    final PermissionStatus status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required for voice notes.')),
        );
      }
      return;
    }
    final String path = await MediaPathHelper.nextPath(folder: 'voice', extension: 'm4a');
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() => _recording = true);
  }

  Future<void> _openDrawing() async {
    final String? path = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (BuildContext context) => const NoteDrawingPage()),
    );
    if (path != null && path.isNotEmpty) {
      _appendLine('![Drawing]($path)');
    }
  }

  Future<void> _scanText() async {
    final XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) {
      return;
    }
    setState(() => _ocrBusy = true);
    try {
      final String text = await widget.onOcrImage(picked.path);
      if (text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No text found in that image.')));
        }
        return;
      }
      _appendLine(text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OCR failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _ocrBusy = false);
      }
    }
  }

  Future<void> _playVoice(String path) async {
    if (_playingPath == path) {
      await _player.stop();
      setState(() => _playingPath = null);
      return;
    }
    if (!File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice file not found.')));
      return;
    }
    await _player.setFilePath(path);
    setState(() => _playingPath = path);
    await _player.play();
    _player.processingStateStream
        .firstWhere((ProcessingState state) => state == ProcessingState.completed)
        .then((_) {
      if (mounted) {
        setState(() => _playingPath = null);
      }
    });
  }

  List<String> _voicePaths(String content) {
    final RegExp re = RegExp(r'\[voice\]\(([^)]+)\)');
    return re.allMatches(content).map((Match m) => m.group(1)!).toList();
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
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(isEditing ? 'Edit note' : 'New note', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: _preview ? 'Edit' : 'Markdown preview',
                    onPressed: () => setState(() => _preview = !_preview),
                    icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                autofocus: !isEditing,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _preview
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Markdown(data: _contentController.text.isEmpty ? '*Nothing to preview*' : _contentController.text),
                      )
                    : TextField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'Markdown content',
                          alignLabelWithHint: true,
                          hintText: '# Heading\n- [ ] Checklist item\n**bold**',
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        onChanged: (_) => setState(() {}),
                      ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  ActionChip(
                    label: const Text('Checklist'),
                    onPressed: () => _appendLine('- [ ] New item'),
                  ),
                  ActionChip(
                    label: const Text('Heading'),
                    onPressed: () => _appendLine('## Section'),
                  ),
                  ActionChip(
                    avatar: Icon(_recording ? Icons.stop : Icons.mic_none, size: 18),
                    label: Text(_recording ? 'Stop' : 'Voice'),
                    onPressed: _toggleRecording,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.brush_outlined, size: 18),
                    label: const Text('Draw'),
                    onPressed: _openDrawing,
                  ),
                  ActionChip(
                    avatar: _ocrBusy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.document_scanner_outlined, size: 18),
                    label: Text(_ocrBusy ? 'Scanning…' : 'OCR'),
                    onPressed: _ocrBusy ? null : _scanText,
                  ),
                ],
              ),
              if (_voicePaths(_contentController.text).isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _voicePaths(_contentController.text).map((String path) {
                    final bool playing = _playingPath == path;
                    return ActionChip(
                      avatar: Icon(playing ? Icons.stop : Icons.play_arrow, size: 18),
                      label: Text(playing ? 'Stop voice' : 'Play voice'),
                      onPressed: () => _playVoice(path),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
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
