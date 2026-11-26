import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// Launcher shortcuts, the Quick Settings tile, and the "Today" home-screen widget, through a
/// small channel to MainActivity. Everything here is best effort: tests have no channel.
abstract final class QuickAccess {
  static const _channel = MethodChannel('dev.basalt.plania/quick');
  static final _actions = StreamController<String>.broadcast();
  static String? _pending;
  static bool _listening = false;

  /// Actions: 'new-task' (tile and shortcut), 'new-note' and 'focus' (shortcuts).
  static const newTask = 'new-task';
  static const newNote = 'new-note';
  static const focus = 'focus';

  /// Shortcut or tile taps that arrive while the app is already open.
  static Stream<String> get actions => _actions.stream;

  static void init() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'action' && call.arguments is String) {
        _pending = call.arguments as String;
        _actions.add(_pending!);
      }
    });
  }

  /// The action that opened the app (or arrived before the home screen was showing), once.
  static Future<String?> takeAction() async {
    final held = _pending;
    _pending = null;
    if (held != null) return held;
    try {
      return await _channel.invokeMethod<String>('takeAction');
    } catch (_) {
      return null;
    }
  }

  /// Delivers an in-app action (a tapped reminder: `task:<id>`) the same way as a shortcut.
  static void dispatch(String action) {
    _pending = action;
    _actions.add(action);
  }

  /// Marks an action from [actions] as handled.
  static void consumed() => _pending = null;

  static Future<void> installShortcuts() async {
    try {
      await _channel.invokeMethod<bool>('installShortcuts');
    } catch (_) {}
  }

  static Future<void> updateWidget(Map<String, Object?> data) async {
    try {
      await _channel.invokeMethod<void>('updateWidget', {'json': jsonEncode(data)});
    } catch (_) {}
  }

  /// Asks the launcher to add the widget. False when the launcher cannot do that.
  static Future<bool> pinWidget() async {
    try {
      return await _channel.invokeMethod<bool>('pinWidget') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the system to add the "New task" tile (Android 13+). False when not supported.
  static Future<bool> addTile() async {
    try {
      return await _channel.invokeMethod<bool>('addTile') ?? false;
    } catch (_) {
      return false;
    }
  }
}
