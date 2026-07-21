import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsService {
  SettingsService(this._box);

  final Box<dynamic> _box;

  static const String boxName = 'lifeos_settings';
  static const String _themeKey = 'theme_mode';
  static const String _languageKey = 'language';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _rememberEmailKey = 'remember_email';
  static const String _biometricKey = 'biometric_enabled';
  static const String _twoFactorKey = 'two_factor_enabled';
  static const String _currentUserIdKey = 'current_user_id';
  static const String _weatherCityKey = 'weather_city';

  ThemeMode get themeMode {
    final String value = _box.get(_themeKey, defaultValue: 'system') as String;
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final String value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _box.put(_themeKey, value);
  }

  String get language => _box.get(_languageKey, defaultValue: 'en') as String;

  Future<void> setLanguage(String language) async {
    await _box.put(_languageKey, language);
  }

  bool get notificationsEnabled => _box.get(_notificationsKey, defaultValue: true) as bool;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _box.put(_notificationsKey, enabled);
  }

  String? get rememberedEmail => _box.get(_rememberEmailKey) as String?;

  Future<void> setRememberedEmail(String? email) async {
    if (email == null || email.isEmpty) {
      await _box.delete(_rememberEmailKey);
    } else {
      await _box.put(_rememberEmailKey, email);
    }
  }

  bool get biometricEnabled => _box.get(_biometricKey, defaultValue: false) as bool;

  Future<void> setBiometricEnabled(bool enabled) async {
    await _box.put(_biometricKey, enabled);
  }

  bool get twoFactorEnabled => _box.get(_twoFactorKey, defaultValue: false) as bool;

  Future<void> setTwoFactorEnabled(bool enabled) async {
    await _box.put(_twoFactorKey, enabled);
  }

  String? get currentUserId => _box.get(_currentUserIdKey) as String?;

  Future<void> setCurrentUserId(String? userId) async {
    if (userId == null) {
      await _box.delete(_currentUserIdKey);
    } else {
      await _box.put(_currentUserIdKey, userId);
    }
  }

  String get weatherCity => _box.get(_weatherCityKey, defaultValue: 'Lahore') as String;

  Future<void> setWeatherCity(String city) async {
    await _box.put(_weatherCityKey, city.trim().isEmpty ? 'Lahore' : city.trim());
  }
}
