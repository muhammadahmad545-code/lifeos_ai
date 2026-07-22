import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/app_updater_service.dart';

const List<Map<String, String>> _languages = <Map<String, String>>[
  <String, String>{'code': 'en', 'label': 'English'},
  <String, String>{'code': 'es', 'label': 'Spanish'},
  <String, String>{'code': 'fr', 'label': 'French'},
  <String, String>{'code': 'de', 'label': 'German'},
  <String, String>{'code': 'ur', 'label': 'Urdu'},
  <String, String>{'code': 'ar', 'label': 'Arabic'},
];

const List<_ModuleLink> _moduleLinks = <_ModuleLink>[
  _ModuleLink(path: '/calendar', label: 'Calendar', icon: Icons.calendar_month_outlined),
  _ModuleLink(path: '/habits', label: 'Habits', icon: Icons.local_fire_department_outlined),
  _ModuleLink(path: '/journal', label: 'Journal', icon: Icons.menu_book_outlined),
  _ModuleLink(path: '/expenses', label: 'Expenses', icon: Icons.account_balance_wallet_outlined),
  _ModuleLink(path: '/goals', label: 'Goals', icon: Icons.flag_outlined),
  _ModuleLink(path: '/focus', label: 'Focus', icon: Icons.timer_outlined),
  _ModuleLink(path: '/health', label: 'Health', icon: Icons.favorite_outline),
  _ModuleLink(path: '/files', label: 'Files', icon: Icons.folder_outlined),
  _ModuleLink(path: '/search', label: 'Search', icon: Icons.search_rounded),
  _ModuleLink(path: '/notifications', label: 'Notifications', icon: Icons.notifications_outlined),
];

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late bool _notificationsEnabled;
  late String _language;
  late final TextEditingController _cityController;
  String _versionLabel = '…';
  bool _checkingUpdate = false;
  bool _downloadingUpdate = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _notificationsEnabled = settings.notificationsEnabled;
    _language = settings.language;
    _cityController = TextEditingController(text: settings.weatherCity);
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() => _versionLabel = '${info.version} (${info.buildNumber})');
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate || _downloadingUpdate) {
      return;
    }
    setState(() => _checkingUpdate = true);
    try {
      final AppUpdateInfo? update = await ref.read(appUpdaterServiceProvider).checkForUpdate();
      if (!mounted) {
        return;
      }
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are on the latest version ($_versionLabel).')),
        );
        return;
      }
      final bool? install = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Update ${update.versionName}'),
          content: Text(
            'A new LIFEOS AI build is available.\n\n${update.notes}\n\n'
            'Tap Update to download and install. Your local data stays on this phone.',
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update')),
          ],
        ),
      );
      if (install == true) {
        await _downloadAndInstall(update);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check failed: $error'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  Future<void> _downloadAndInstall(AppUpdateInfo update) async {
    setState(() {
      _downloadingUpdate = true;
      _downloadProgress = 0;
    });
    try {
      final AppUpdaterService updater = ref.read(appUpdaterServiceProvider);
      final file = await updater.downloadApk(
        update,
        onProgress: (double value) {
          if (mounted) {
            setState(() => _downloadProgress = value);
          }
        },
      );
      await updater.installApk(file);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Install failed: $error'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingUpdate = false);
      }
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await ref.read(settingsServiceProvider).setNotificationsEnabled(value);
  }

  Future<void> _setLanguage(String? code) async {
    if (code == null) {
      return;
    }
    setState(() => _language = code);
    await ref.read(settingsServiceProvider).setLanguage(code);
  }

  Future<void> _signOut() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime with your email or biometrics.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: _versionLabel,
      applicationLegalese: AppConstants.tagline,
      children: <Widget>[
        const SizedBox(height: 12),
        const Text(
          'LIFEOS AI runs fully offline: your tasks, notes, habits, journal, expenses, goals, and '
          'assistant conversations are stored locally on this device.',
        ),
        const SizedBox(height: 8),
        Text('Updates: ${AppConstants.githubReleasesUrl}'),
      ],
    );
  }

  Future<void> _exportBackup() async {
    final String? userId = ref.read(authSessionProvider).valueOrNull?.id;
    if (userId == null) {
      return;
    }
    try {
      await ref.read(backupServiceProvider).shareBackup(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup ready to share.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final themeController = ref.read(themeModeProvider.notifier);
    final user = ref.watch(authSessionProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?'),
                  ),
                  title: Text(user.displayName),
                  subtitle: Text(user.email),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile'),
                ),
              ),
            ),
          const _SectionLabel('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment<ThemeMode>(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                ButtonSegment<ThemeMode>(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
              ],
              selected: <ThemeMode>{themeMode},
              onSelectionChanged: (Set<ThemeMode> value) => themeController.setThemeMode(value.first),
            ),
          ),
          const _SectionLabel('Preferences'),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Receive reminders and alerts'),
            value: _notificationsEnabled,
            onChanged: _setNotifications,
          ),
          ListTile(
            title: const Text('Language'),
            subtitle: Text(_languages.firstWhere((Map<String, String> l) => l['code'] == _language)['label']!),
            trailing: DropdownButton<String>(
              value: _language,
              underline: const SizedBox.shrink(),
              items: _languages
                  .map((Map<String, String> l) => DropdownMenuItem<String>(value: l['code'], child: Text(l['label']!)))
                  .toList(),
              onChanged: _setLanguage,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'Weather city',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: () async {
                    final String city = _cityController.text.trim();
                    await ref.read(settingsServiceProvider).setWeatherCity(city);
                    ref.invalidate(weatherProvider);
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Weather city set to $city')),
                    );
                  },
                ),
              ),
            ),
          ),
          const _SectionLabel('Modules'),
          ..._moduleLinks.map(
            (_ModuleLink link) => ListTile(
              leading: Icon(link.icon),
              title: Text(link.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(link.path),
            ),
          ),
          const _SectionLabel('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Privacy & Security'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/security'),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Admin dashboard'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/admin'),
          ),
          const _SectionLabel('Backup'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Export & share backup'),
            subtitle: const Text('Save tasks, notes, habits, journal, expenses, goals'),
            trailing: const Icon(Icons.ios_share_rounded),
            onTap: _exportBackup,
          ),
          const _SectionLabel('Updates'),
          ListTile(
            leading: _checkingUpdate || _downloadingUpdate
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.system_update_outlined),
            title: Text(_downloadingUpdate ? 'Downloading update…' : 'Check for updates'),
            subtitle: Text(
              _downloadingUpdate
                  ? '${(_downloadProgress * 100).round()}% — keep the app open'
                  : 'Current version $_versionLabel',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _checkingUpdate || _downloadingUpdate ? null : _checkForUpdates,
          ),
          if (_downloadingUpdate)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: LinearProgressIndicator(value: _downloadProgress <= 0 ? null : _downloadProgress),
            ),
          const _SectionLabel('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About LIFEOS AI'),
            subtitle: Text('Version $_versionLabel'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAbout,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _ModuleLink {
  const _ModuleLink({required this.path, required this.label, required this.icon});

  final String path;
  final String label;
  final IconData icon;
}
