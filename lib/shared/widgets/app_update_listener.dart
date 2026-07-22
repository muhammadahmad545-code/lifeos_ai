import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/services/app_updater_service.dart';

class AppUpdateListener extends ConsumerStatefulWidget {
  const AppUpdateListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateListener> createState() => _AppUpdateListenerState();
}

class _AppUpdateListenerState extends ConsumerState<AppUpdateListener> {
  AppUpdateInfo? _update;
  bool _dismissed = false;
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    try {
      final AppUpdateInfo? update = await ref.read(appUpdaterServiceProvider).checkForUpdate();
      if (!mounted || update == null) {
        return;
      }
      setState(() {
        _update = update;
        _dismissed = false;
        _error = null;
      });
      if (!_notified && ref.read(settingsServiceProvider).notificationsEnabled) {
        _notified = true;
        await ref.read(localNotificationServiceProvider).showNow(
              id: 91001,
              title: 'LIFEOS AI update available',
              body: 'Version ${update.versionName} is ready. Open the app to install.',
            );
      }
    } catch (_) {
      // Silent on startup — Settings has a manual check.
    }
  }

  Future<void> _install() async {
    final AppUpdateInfo? update = _update;
    if (update == null || _downloading) {
      return;
    }
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final AppUpdaterService updater = ref.read(appUpdaterServiceProvider);
      final file = await updater.downloadApk(
        update,
        onProgress: (double value) {
          if (mounted) {
            setState(() => _progress = value);
          }
        },
      );
      await updater.installApk(file);
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppUpdateInfo? update = _update;
    final bool showBanner = update != null && !_dismissed;

    return Stack(
      children: <Widget>[
        widget.child,
        if (showBanner)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                elevation: 6,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.system_update, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _downloading
                                  ? 'Downloading ${update.versionName}… ${(_progress * 100).round()}%'
                                  : 'Update ${update.versionName} available',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          if (!_downloading)
                            TextButton(
                              onPressed: _install,
                              child: const Text('Update'),
                            ),
                          IconButton(
                            tooltip: 'Dismiss',
                            onPressed: () => setState(() => _dismissed = true),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      if (_downloading)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: LinearProgressIndicator(value: _progress <= 0 ? null : _progress),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
