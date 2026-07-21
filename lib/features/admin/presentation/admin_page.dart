import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/premium_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../notifications/domain/app_notification.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final String text = _feedbackController.text.trim();
    final String? userId = _userId;
    if (text.isEmpty || userId == null) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(notificationRepositoryProvider).addNotification(
            userId,
            AppNotification(id: '', title: 'Feedback submitted', body: text, type: 'feedback'),
          );
      _feedbackController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks! Your feedback was recorded.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int taskCount = ref.watch(watchTasksProvider).valueOrNull?.length ?? 0;
    final int noteCount = ref.watch(watchNotesProvider).valueOrNull?.length ?? 0;
    final int habitCount = ref.watch(watchHabitsProvider).valueOrNull?.length ?? 0;
    final int goalCount = ref.watch(watchGoalsProvider).valueOrNull?.length ?? 0;
    final int expenseCount = ref.watch(watchExpensesProvider).valueOrNull?.length ?? 0;
    final int journalCount = ref.watch(watchJournalEntriesProvider).valueOrNull?.length ?? 0;
    final int eventCount = ref.watch(watchCalendarEventsProvider).valueOrNull?.length ?? 0;
    final int fileCount = ref.watch(watchFilesProvider).valueOrNull?.length ?? 0;
    final int notificationCount = ref.watch(watchNotificationsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const SectionHeader(title: 'System overview', subtitle: 'Live counts from the local database'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: <Widget>[
              _StatCard(icon: Icons.check_circle_outline, label: 'Tasks', value: taskCount),
              _StatCard(icon: Icons.sticky_note_2_outlined, label: 'Notes', value: noteCount),
              _StatCard(icon: Icons.repeat_rounded, label: 'Habits', value: habitCount),
              _StatCard(icon: Icons.flag_outlined, label: 'Goals', value: goalCount),
              _StatCard(icon: Icons.payments_outlined, label: 'Transactions', value: expenseCount),
              _StatCard(icon: Icons.menu_book_outlined, label: 'Journal entries', value: journalCount),
              _StatCard(icon: Icons.event_outlined, label: 'Events', value: eventCount),
              _StatCard(icon: Icons.folder_outlined, label: 'Files', value: fileCount),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'System'),
          const SizedBox(height: 12),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bug_report_outlined),
                  title: Text('Crashlytics'),
                  subtitle: Text('Local mode — crash reporting is disabled. All data stays on this device.'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notifications queued'),
                  trailing: Text('$notificationCount'),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Storage engine'),
                  subtitle: Text('Drift (SQLite) — offline-first, no server dependency'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Feedback', subtitle: 'Send a note to yourself or your future self'),
          const SizedBox(height: 12),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _feedbackController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Feedback or bug report',
                    hintText: 'Describe what you noticed...',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: const Text('Submit feedback'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
