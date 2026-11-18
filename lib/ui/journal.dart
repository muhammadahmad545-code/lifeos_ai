import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/assistant.dart';
import '../logic/dates.dart';
import '../providers.dart';
import 'common.dart';

IconData moodIcon(String? mood) => switch (mood) {
      'great' => Icons.sentiment_very_satisfied_rounded,
      'good' => Icons.sentiment_satisfied_rounded,
      'okay' => Icons.sentiment_neutral_rounded,
      'low' => Icons.sentiment_dissatisfied_rounded,
      'rough' => Icons.sentiment_very_dissatisfied_rounded,
      _ => Icons.edit_note_rounded,
    };

class JournalPage extends ConsumerWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.basalt;
    final entries = ref.watch(journalProvider).list;
    final now = DateTime.now();
    final wroteToday = entries.any((e) => sameDay(e.createdAt, now));

    final byMonth = <String, List<JournalEntryRow>>{};
    for (final e in entries) {
      byMonth.putIfAbsent(DateFormat('MMMM y').format(e.createdAt), () => []).add(e);
    }

    return SubPage(
      title: 'Journal',
      subtitle: entries.isEmpty ? null : (wroteToday ? 'You wrote today' : 'How was your day?'),
      floating: AddButton(label: 'New entry', onPressed: () => push(context, const JournalEditor())),
      children: [
        if (entries.isEmpty)
          BEmptyState(
            icon: Icons.book_outlined,
            title: 'Your journal is empty',
            message: 'A few lines a day and a mood. Only you can read it.',
            actionLabel: 'Write today',
            onAction: () => push(context, const JournalEditor()),
          )
        else
          for (final m in byMonth.entries) ...[
            BSectionTitle(m.key),
            for (final e in m.value)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: BCard(
                  onTap: () => push(context, JournalEditor(entry: e)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MoodBadge(mood: e.mood),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title.trim().isEmpty ? relativeDay(e.createdAt, now: now) : e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BasaltType.heading.copyWith(color: p.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                fmtDate(e.createdAt, now: now),
                                if (e.mood != null && e.mood!.isNotEmpty) moodLabel(e.mood!),
                              ].join(' · '),
                              style: BasaltType.caption.copyWith(color: p.textFaint),
                            ),
                            if (e.content.trim().isNotEmpty) ...[
                              const SizedBox(height: Gap.xs),
                              Text(e.content.trim(), maxLines: 3, overflow: TextOverflow.ellipsis, style: BasaltType.body.copyWith(color: p.textMuted, fontSize: 14)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
      ],
    );
  }
}

class _MoodBadge extends StatelessWidget {
  const _MoodBadge({required this.mood});

  final String? mood;

  @override
  Widget build(BuildContext context) {
    final m = mood;
    // 1.x entries stored an emoji.
    if (m != null && m.isNotEmpty && !kMoods.containsKey(m)) {
      final p = context.basalt;
      return Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(Radii.md)),
        child: Text(m, style: BasaltType.title),
      );
    }
    return BIconTile(moodIcon(m));
  }
}

class JournalEditor extends ConsumerStatefulWidget {
  const JournalEditor({super.key, this.entry});

  final JournalEntryRow? entry;

  @override
  ConsumerState<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends ConsumerState<JournalEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.entry?.title ?? '');
  late final TextEditingController _body = TextEditingController(text: widget.entry?.content ?? '');
  late String? _mood = widget.entry?.mood;
  late DateTime _date = widget.entry?.createdAt ?? DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty && body.isEmpty) {
      BToast.show(context, 'Write something first');
      return;
    }
    await ref.read(repoProvider).saveJournal(id: widget.entry?.id, title: title, content: body, mood: _mood, date: _date);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await bConfirm(context, title: 'Delete entry?', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    await ref.read(repoProvider).deleteJournal(widget.entry!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      title: widget.entry == null ? 'New entry' : 'Edit entry',
      onSave: _save,
      actions: [
        if (widget.entry != null) IconAction(icon: Icons.delete_outline_rounded, label: 'Delete entry', onPressed: _delete),
      ],
      children: [
        PickerField(
          icon: Icons.event_rounded,
          label: relativeDay(_date),
          onTap: () async {
            final d = await pickDate(context, _date);
            if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
          },
        ),
        const FieldLabel('Mood'),
        ChipWrap(
          children: [
            for (final m in kMoods.entries)
              BChip(
                label: m.value,
                icon: moodIcon(m.key),
                selected: _mood == m.key,
                onTap: () => setState(() => _mood = _mood == m.key ? null : m.key),
              ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Title (optional)'),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _body,
          autofocus: widget.entry == null,
          minLines: 8,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What happened today? What are you grateful for?', alignLabelWithHint: true),
        ),
      ],
    );
  }
}
