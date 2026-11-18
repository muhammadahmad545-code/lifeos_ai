import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/assistant.dart';
import '../providers.dart';
import 'common.dart';

class _Message {
  const _Message(this.text, {required this.fromUser});
  final String text;
  final bool fromUser;
}

/// Rule-based assistant over the user's own data. Runs on the device; nothing is sent anywhere.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Assistant _assistant() => Assistant(
        AssistantData(
          tasks: ref.read(tasksProvider).list,
          events: ref.read(eventsProvider).list,
          habits: ref.read(habitsProvider).list,
          habitDays: ref.read(habitDaysProvider),
          expenses: ref.read(expensesProvider).list,
          budgets: ref.read(budgetsProvider).list,
          goals: ref.read(goalsProvider).list,
          focus: ref.read(focusSessionsProvider).list,
          journal: ref.read(journalProvider).list,
          notes: ref.read(notesProvider).list,
        ),
        money: ref.read(moneyProvider).call,
        now: DateTime.now(),
      );

  void _ask(String question, {AssistantTopic? topic}) {
    final q = question.trim();
    if (q.isEmpty) return;
    final a = _assistant();
    setState(() {
      _messages.add(_Message(q, fromUser: true));
      _messages.add(_Message(topic != null ? a.answerTopic(topic) : a.answer(q), fromUser: false));
    });
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    // Keep the data streams alive while this screen is open.
    ref
      ..watch(tasksProvider)
      ..watch(eventsProvider)
      ..watch(habitsProvider)
      ..watch(habitLogsProvider)
      ..watch(expensesProvider)
      ..watch(budgetsProvider)
      ..watch(goalsProvider)
      ..watch(focusSessionsProvider)
      ..watch(journalProvider)
      ..watch(notesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Assistant')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
                children: [
                  BCard(
                    color: p.accentSoft,
                    borderColor: p.accentSoft,
                    child: Row(
                      children: [
                        Icon(Icons.offline_bolt_outlined, color: p.accent),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(
                            'On-device, no internet. Answers come from your own tasks, calendar, habits, expenses, goals and journal.',
                            style: BasaltType.caption.copyWith(color: p.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  if (_messages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                      child: Text('Pick a question below or type your own.', textAlign: TextAlign.center, style: BasaltType.body.copyWith(color: p.textMuted)),
                    ),
                  for (final m in _messages) _Bubble(message: m),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.xs),
                children: [
                  for (final e in kAssistantPrompts.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: Gap.sm),
                      child: BChip(label: e.value, onTap: () => _ask(e.value, topic: e.key)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.sm, Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: _ask,
                      decoration: const InputDecoration(hintText: 'Ask about your day, money, habits…'),
                    ),
                  ),
                  IconAction(icon: Icons.send_rounded, label: 'Send', color: p.accent, onPressed: () => _ask(_input.text)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (user ? 0.75 : 0.9)),
        padding: const EdgeInsets.symmetric(horizontal: Gap.md + 2, vertical: Gap.md - 2),
        decoration: BoxDecoration(
          color: user ? p.accent : p.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: user ? null : Border.all(color: p.border),
        ),
        child: SelectableText(
          message.text,
          style: BasaltType.body.copyWith(color: user ? p.onAccent : p.text, fontSize: 14.5, height: 1.45),
        ),
      ),
    );
  }
}
