import 'dart:convert';
import 'dart:typed_data';

import 'package:basalt/basalt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../data/backup.dart';
import '../data/backup_crypto.dart';
import '../logic/dates.dart';
import '../providers.dart';
import '../services/app_lock.dart';
import '../services/quick_access.dart';
import '../services/reminders.dart';
import 'common.dart';

final _notificationStatusProvider = FutureProvider.autoDispose<(bool, bool)>((ref) async {
  final r = Reminders.instance;
  return (await r.notificationsAllowed(), await r.exactAlarmsAllowed());
});

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;
  String? _busyLabel;

  Future<void> _toggleLock(bool on) async {
    final settings = ref.read(settingsProvider.notifier);
    if (!on) {
      await settings.setAppLock(false);
      return;
    }
    if (!await AppLock.available()) {
      if (mounted) BToast.show(context, 'Set a screen lock (PIN, pattern or fingerprint) on this phone first');
      return;
    }
    // Confirm it works before turning it on, so nobody gets locked out.
    if (await AppLock.authenticate()) {
      await settings.setAppLock(true);
      if (mounted) BToast.show(context, 'App lock is on');
    }
  }

  /// Asks for the backup passphrase. Returns null when cancelled and '' when the user chose
  /// to save without one.
  Future<String?> _askExportPassphrase() {
    final pass = TextEditingController();
    final confirm = TextEditingController();
    final confirmFocus = FocusNode();
    String? error;
    return showFormSheet<String>(
      context,
      title: 'Protect this backup',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final p = ctx.basalt;
          void submit() {
            if (pass.text.length < BackupCrypto.minPassphraseLength) {
              setSheet(() => error = 'Use at least ${BackupCrypto.minPassphraseLength} characters');
            } else if (pass.text != confirm.text) {
              setSheet(() => error = 'The passphrases do not match');
            } else {
              Navigator.of(ctx).pop(pass.text);
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'The file is encrypted with AES-256 and can only be imported with this passphrase. '
                'Plania cannot recover a forgotten passphrase.',
                style: BasaltType.body.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: Gap.lg),
              TextField(
                controller: pass,
                autofocus: true,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => confirmFocus.requestFocus(),
                decoration: const InputDecoration(labelText: 'Passphrase'),
              ),
              const SizedBox(height: Gap.md),
              TextField(
                controller: confirm,
                focusNode: confirmFocus,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(labelText: 'Repeat passphrase', errorText: error),
              ),
              const SizedBox(height: Gap.lg),
              BButton(label: 'Encrypt and save', icon: Icons.lock_outline_rounded, expand: true, onPressed: submit),
              const SizedBox(height: Gap.sm),
              BButton(
                label: 'Skip, save without a passphrase',
                variant: BButtonVariant.ghost,
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(''),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _export() async {
    final passphrase = await _askExportPassphrase();
    if (passphrase == null || !mounted) return;
    final encrypt = passphrase.isNotEmpty;
    setState(() {
      _busy = true;
      _busyLabel = encrypt ? 'Encrypting…' : 'Preparing…';
    });
    try {
      final json = await Backup(ref.read(dbProvider)).export();
      final out = encrypt ? await encryptBackupInBackground(json, passphrase) : json;
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Plania backup',
        fileName: 'plania-backup-${dayKey(DateTime.now())}${encrypt ? '-encrypted' : ''}.json',
        bytes: Uint8List.fromList(utf8.encode(out)),
      );
      if (mounted && path != null) BToast.show(context, encrypt ? 'Encrypted backup saved' : 'Backup saved');
    } catch (e) {
      if (mounted) BToast.show(context, 'Could not save the backup: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<String?> _askImportPassphrase() {
    final pass = TextEditingController();
    return showFormSheet<String>(
      context,
      title: 'Encrypted backup',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This backup is protected. Enter the passphrase it was saved with.',
            style: BasaltType.body.copyWith(color: ctx.basalt.textMuted),
          ),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: pass,
            autofocus: true,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) {
              if (v.isNotEmpty) Navigator.of(ctx).pop(v);
            },
            decoration: const InputDecoration(labelText: 'Passphrase'),
          ),
          const SizedBox(height: Gap.lg),
          BButton(
            label: 'Unlock',
            icon: Icons.lock_open_rounded,
            expand: true,
            onPressed: () {
              if (pass.text.isNotEmpty) Navigator.of(ctx).pop(pass.text);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showError(String title, String message) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  Future<void> _import() async {
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    } catch (e) {
      if (mounted) BToast.show(context, 'Could not open the file: $e');
      return;
    }
    final bytes = picked?.files.single.bytes;
    if (bytes == null || !mounted) return;
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      BToast.show(context, 'This file is not a Plania backup.');
      return;
    }
    if (BackupCrypto.isEncrypted(text)) {
      final passphrase = await _askImportPassphrase();
      if (passphrase == null || !mounted) return;
      setState(() {
        _busy = true;
        _busyLabel = 'Decrypting…';
      });
      try {
        text = await decryptBackupInBackground(text, passphrase);
      } on BackupPassphraseException {
        if (mounted) {
          await _showError('Wrong passphrase', 'That passphrase does not open this backup. Nothing was imported or changed.');
        }
        return;
      } on BackupFormatException catch (e) {
        if (mounted) BToast.show(context, e.message);
        return;
      } finally {
        if (mounted) {
          setState(() {
            _busy = false;
            _busyLabel = null;
          });
        }
      }
      if (!mounted) return;
    }
    final Map<String, int> counts;
    try {
      counts = Backup.inspect(text);
    } on BackupFormatException catch (e) {
      BToast.show(context, e.message);
      return;
    } on FormatException {
      BToast.show(context, 'This file is not a Plania backup.');
      return;
    }
    final total = counts.values.fold<int>(0, (s, v) => s + v);
    if (total == 0) {
      BToast.show(context, 'This backup is empty');
      return;
    }
    final ok = await bConfirm(
      context,
      title: 'Import backup?',
      message: '$total items will be added. Items that already exist are updated, nothing is deleted.',
      confirmLabel: 'Import',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final n = await Backup(ref.read(dbProvider)).import(text);
      await Reminders.instance.syncAll(await ref.read(repoProvider).allTasks());
      if (mounted) BToast.show(context, 'Imported $n items');
    } on BackupFormatException catch (e) {
      if (mounted) BToast.show(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final s = ref.watch(settingsProvider);
    final status = ref.watch(_notificationStatusProvider).valueOrNull;

    return SubPage(
      title: 'Settings',
      children: [
        const BSectionTitle('Appearance'),
        BCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BListRow(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: '${switch (s.themeMode) { ThemeMode.light => 'Light', ThemeMode.dark => 'Dark', _ => 'System' }} theme · colour, font, text size, layout and motion',
                chevron: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => BasaltAppearanceScreen(
                    appName: 'Plania',
                    appAccent: kAccent,
                    themeMode: s.themeMode,
                    onThemeMode: (m) => ref.read(settingsProvider.notifier).setThemeMode(m),
                  ),
                )),
              ),
              const SizedBox(height: Gap.lg),
              Text('Currency', style: BasaltType.label.copyWith(color: p.textMuted)),
              const SizedBox(height: Gap.sm),
              ChipWrap(
                children: [
                  for (final c in kCurrencies)
                    BChip(label: c, selected: s.currency == c, onTap: () => ref.read(settingsProvider.notifier).setCurrency(c)),
                ],
              ),
            ],
          ),
        ),
        BGroup(
          title: 'Reminders',
          children: [
            BListRow(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: status == null
                  ? 'Checking…'
                  : (status.$1 ? 'Allowed' : 'Off. Tap to allow task reminders and the focus alarm.'),
              trailing: status != null && status.$1 ? Icon(Icons.check_rounded, color: p.success) : null,
              onTap: () async {
                await Reminders.instance.ensurePermission();
                ref.invalidate(_notificationStatusProvider);
              },
            ),
            BListRow(
              icon: Icons.alarm_rounded,
              title: 'On-time delivery',
              subtitle: status == null
                  ? 'Checking…'
                  : (status.$2 ? 'Exact alarms allowed: reminders arrive on the minute' : 'Reminders may arrive a few minutes late'),
            ),
            BListRow(
              icon: Icons.send_outlined,
              title: 'Send a test notification',
              subtitle: 'Reminders have Mark done and Snooze 10 min buttons',
              onTap: () async {
                if (await Reminders.instance.ensurePermission()) {
                  await Reminders.instance.showTest();
                } else if (context.mounted) {
                  BToast.show(context, 'Notifications are off for Plania in system settings');
                }
                ref.invalidate(_notificationStatusProvider);
              },
            ),
          ],
        ),
        BGroup(
          title: 'Privacy',
          children: [
            SwitchRow(
              icon: Icons.lock_outline_rounded,
              title: 'App lock',
              subtitle: 'Ask for your fingerprint, face or phone PIN when Plania opens',
              value: s.appLock,
              onChanged: _toggleLock,
            ),
          ],
        ),
        BGroup(
          title: 'Quick access',
          children: [
            BListRow(
              icon: Icons.widgets_outlined,
              title: 'Home-screen widget',
              subtitle: 'Tasks due, habits and your next event. Tap to add it.',
              onTap: () async {
                final shown = await QuickAccess.pinWidget();
                if (shown || !context.mounted) return;
                BToast.show(context, 'Long-press your home screen, tap Widgets and pick Plania');
              },
            ),
            BListRow(
              icon: Icons.add_task_rounded,
              title: 'Quick Settings tile',
              subtitle: 'New task, from anywhere. Tap to add it.',
              onTap: () async {
                final shown = await QuickAccess.addTile();
                if (shown || !context.mounted) return;
                BToast.show(context, 'Pull down Quick Settings, tap the pencil and drag in New task');
              },
            ),
            const BListRow(
              icon: Icons.touch_app_outlined,
              title: 'Launcher shortcuts',
              subtitle: 'Long-press the app icon: New task, New note, Start focus.',
            ),
          ],
        ),
        BGroup(
          title: 'Your data',
          children: [
            BListRow(
              icon: Icons.upload_file_rounded,
              title: 'Export backup',
              subtitle: _busyLabel ?? 'Save everything as a file, encrypted with a passphrase',
              onTap: _busy ? null : _export,
              trailing: _busy ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)) : null,
            ),
            BListRow(
              icon: Icons.download_rounded,
              title: 'Import backup',
              subtitle: 'Merge a Plania backup (plain or encrypted) into this phone',
              onTap: _busy ? null : _import,
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        const UpdatesSection(),
        const SizedBox(height: Gap.lg),
        Text(
          'Plania keeps everything on this phone. No account, no cloud, no tracking. '
          'The only network use is checking GitHub for app updates.',
          textAlign: TextAlign.center,
          style: BasaltType.caption.copyWith(color: p.textFaint),
        ),
      ],
    );
  }
}
