import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../logic/rules.dart';
import '../providers.dart';
import 'common.dart';

bool noteMatches(NoteRow n, String q) {
  if (q.isEmpty) return true;
  final s = q.toLowerCase();
  return n.title.toLowerCase().contains(s) ||
      n.content.toLowerCase().contains(s) ||
      decodeChecklist(n.checklist).any((i) => i.text.toLowerCase().contains(s));
}

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider).list;
    final shown = notes.where((n) => noteMatches(n, _query.trim())).toList();
    final pinned = shown.where((n) => n.isPinned).toList();
    final others = shown.where((n) => !n.isPinned).toList();

    return BPage(
      title: 'Notes',
      subtitle: notes.isEmpty ? null : '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
      floating: AddButton(label: 'New note', onPressed: () => push(context, const NoteEditor())),
      children: [
        if (notes.isNotEmpty) BSearchField(hint: 'Search notes', onChanged: (v) => setState(() => _query = v)),
        if (notes.isEmpty)
          BEmptyState(
            icon: Icons.sticky_note_2_outlined,
            title: 'No notes yet',
            message: 'Write ideas, lists and checklists. Pin the ones you need often.',
            actionLabel: 'New note',
            onAction: () => push(context, const NoteEditor()),
          )
        else if (shown.isEmpty)
          const BEmptyState(icon: Icons.search_off_rounded, title: 'No matching notes')
        else ...[
          if (pinned.isNotEmpty) ...[
            const BSectionTitle('Pinned'),
            for (final n in pinned) NoteCard(note: n),
          ],
          if (others.isNotEmpty) ...[
            if (pinned.isNotEmpty) const BSectionTitle('Others') else const SizedBox(height: Gap.md),
            for (final n in others) NoteCard(note: n),
          ],
        ],
        const SizedBox(height: 72),
      ],
    );
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note});

  final NoteRow note;

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final items = decodeChecklist(note.checklist);
    final done = items.where((i) => i.done).length;
    final preview = note.content.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: BCard(
        onTap: () => push(context, NoteEditor(note: note)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title.trim().isEmpty ? 'Untitled' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BasaltType.heading.copyWith(color: p.text),
                  ),
                ),
                if (note.isPinned) Icon(Icons.push_pin_rounded, size: 16, color: p.accent),
              ],
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: Gap.xs),
              Text(preview, maxLines: 3, overflow: TextOverflow.ellipsis, style: BasaltType.body.copyWith(color: p.textMuted, fontSize: 14)),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              for (final i in items.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(i.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 16, color: i.done ? p.accent : p.textFaint),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          i.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BasaltType.body.copyWith(
                            fontSize: 14,
                            color: i.done ? p.textFaint : p.text,
                            decoration: i.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: Gap.sm),
            Text(
              [
                fmtDate(note.updatedAt),
                if (items.isNotEmpty) '$done/${items.length} done',
              ].join(' · '),
              style: BasaltType.caption.copyWith(color: p.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item {
  _Item(String text, this.done) : controller = TextEditingController(text: text);
  final TextEditingController controller;
  bool done;
}

/// Note editor. Changes are saved when you leave the screen.
class NoteEditor extends ConsumerStatefulWidget {
  const NoteEditor({super.key, this.note});

  final NoteRow? note;

  @override
  ConsumerState<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<NoteEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.note?.title ?? '');
  late final TextEditingController _body = TextEditingController(text: widget.note?.content ?? '');
  late final List<_Item> _items = [
    for (final i in decodeChecklist(widget.note?.checklist ?? '')) _Item(i.text, i.done),
  ];
  late bool _pinned = widget.note?.isPinned ?? false;
  int? _focusItem;
  bool _deleted = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    for (final i in _items) {
      i.controller.dispose();
    }
    super.dispose();
  }

  String get _checklist => encodeChecklist([for (final i in _items) CheckItem(i.controller.text, done: i.done)]);

  void _persist() {
    if (_deleted) return;
    final repo = ref.read(repoProvider);
    final n = widget.note;
    final title = _title.text.trim();
    final body = _body.text.trimRight();
    final list = _checklist;
    final empty = title.isEmpty && body.trim().isEmpty && list.isEmpty;
    if (n == null) {
      if (!empty) repo.saveNote(title: title, content: body, checklist: list, pinned: _pinned);
      return;
    }
    if (empty) {
      repo.deleteNote(n.id);
      return;
    }
    if (title == n.title && body == n.content && list == n.checklist && _pinned == n.isPinned) return;
    repo.saveNote(id: n.id, title: title, content: body, checklist: list, pinned: _pinned);
  }

  Future<void> _delete() async {
    final ok = await bConfirm(context, title: 'Delete note?', confirmLabel: 'Delete', danger: true);
    if (!ok || !mounted) return;
    _deleted = true;
    if (widget.note != null) await ref.read(repoProvider).deleteNote(widget.note!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    const plain = InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: Gap.sm),
    );
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _persist();
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconAction(
              icon: _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              label: _pinned ? 'Unpin' : 'Pin',
              color: _pinned ? p.accent : null,
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            if (widget.note != null) IconAction(icon: Icons.delete_outline_rounded, label: 'Delete note', onPressed: _delete),
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Done')),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.xl - 4, Gap.sm, Gap.xl - 4, Gap.xxxl),
          children: [
            TextField(
              controller: _title,
              autofocus: widget.note == null,
              textCapitalization: TextCapitalization.sentences,
              style: BasaltType.title.copyWith(color: p.text),
              decoration: plain.copyWith(hintText: 'Title'),
            ),
            TextField(
              controller: _body,
              minLines: 4,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: BasaltType.body.copyWith(color: p.text, height: 1.5),
              decoration: plain.copyWith(hintText: 'Start writing'),
            ),
            if (_items.isNotEmpty) const BSectionTitle('Checklist'),
            for (var i = 0; i < _items.length; i++)
              Row(
                key: ObjectKey(_items[i]),
                children: [
                  CheckCircle(
                    done: _items[i].done,
                    label: _items[i].done ? 'Uncheck ${_items[i].controller.text}' : 'Check ${_items[i].controller.text}',
                    onTap: () => setState(() => _items[i].done = !_items[i].done),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _items[i].controller,
                      autofocus: _focusItem == i,
                      textCapitalization: TextCapitalization.sentences,
                      style: BasaltType.body.copyWith(
                        color: _items[i].done ? p.textFaint : p.text,
                        decoration: _items[i].done ? TextDecoration.lineThrough : null,
                      ),
                      onSubmitted: (_) => setState(() {
                        _items.insert(i + 1, _Item('', false));
                        _focusItem = i + 1;
                      }),
                      decoration: plain.copyWith(hintText: 'List item'),
                    ),
                  ),
                  IconAction(
                    icon: Icons.close_rounded,
                    label: 'Remove item',
                    size: 18,
                    onPressed: () {
                      final removed = _items[i];
                      setState(() {
                        _items.removeAt(i);
                        _focusItem = null;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) => removed.controller.dispose());
                    },
                  ),
                ],
              ),
            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: BButton(
                label: 'Add checklist item',
                icon: Icons.add_task_rounded,
                variant: BButtonVariant.ghost,
                onPressed: () => setState(() {
                  _items.add(_Item('', false));
                  _focusItem = _items.length - 1;
                }),
              ),
            ),
            if (widget.note != null) ...[
              const SizedBox(height: Gap.lg),
              Text(
                'Edited ${fmtDate(widget.note!.updatedAt)} ${fmtTime(widget.note!.updatedAt)}',
                style: BasaltType.caption.copyWith(color: p.textFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
