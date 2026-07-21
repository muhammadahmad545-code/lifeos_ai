import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../expenses/domain/expense.dart';
import '../../goals/domain/goal.dart';
import '../../habits/domain/habit.dart';
import '../../journal/domain/journal_entry.dart';
import '../../notes/domain/note.dart';
import '../../tasks/domain/task.dart';
import '../domain/chat_message.dart';

const List<String> _suggestions = <String>[
  'Plan my day',
  'Prioritize my tasks',
  'Summarize notes',
  'Habit tips',
  'Expense insights',
  'Overview',
];

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _send([String? text]) async {
    final String message = (text ?? _controller.text).trim();
    final String? userId = _userId;
    if (message.isEmpty || userId == null || _isSending) {
      return;
    }
    _controller.clear();
    setState(() => _isSending = true);
    try {
      final assistantRepo = ref.read(assistantRepositoryProvider);
      await assistantRepo.addMessage(userId, ChatMessage(id: '', role: 'user', content: message));
      _scrollToBottom();

      final List<Task> tasks = await ref.read(taskRepositoryProvider).getTasks(userId);
      final List<Note> notes = await ref.read(noteRepositoryProvider).getNotes(userId);
      final List<Habit> habits = await ref.read(habitRepositoryProvider).getHabits(userId);
      final List<Expense> expenses = await ref.read(expenseRepositoryProvider).getExpenses(userId);
      final List<Goal> goals = await ref.read(goalRepositoryProvider).getGoals(userId);
      final List<JournalEntry> journal = await ref.read(journalRepositoryProvider).getEntries(userId);

      final String reply = ref.read(lifeOsAiEngineProvider).respond(
            userMessage: message,
            tasks: tasks,
            notes: notes,
            habits: habits,
            expenses: expenses,
            goals: goals,
            journal: journal,
          );

      await assistantRepo.addMessage(userId, ChatMessage(id: '', role: 'assistant', content: reply));
      _scrollToBottom();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _clearHistory() async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This removes all chat history with your LifeOS assistant.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(assistantRepositoryProvider).clearHistory(userId);
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ChatMessage>> messagesAsync = ref.watch(watchChatMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear history',
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: messagesAsync.when(
              data: (List<ChatMessage> messages) {
                if (messages.isEmpty) {
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: 24),
                          Icon(Icons.auto_awesome_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 16),
                          const EmptyStateView(
                            title: 'Ask your LifeOS assistant',
                            message: 'Fully offline — works with your tasks, notes, habits, expenses, goals and journal.',
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _suggestions
                                .map((String s) => ActionChip(label: Text(s), onPressed: () => _send(s)))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ChatMessage message = messages[index];
                    return _MessageBubble(message: message);
                  },
                );
              },
              loading: () => const LoadingView(),
              error: (Object error, StackTrace stack) => ErrorView(error: error),
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask me anything about your life...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _isSending ? null : () => _send(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                message.content,
                style: TextStyle(color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
              ),
              if (message.createdAt != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm().format(message.createdAt!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: (isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
