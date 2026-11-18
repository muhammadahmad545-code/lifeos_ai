import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefsProvider is set in main()'));

const List<String> kCurrencies = [r'$', '€', '£', 'Rs', '₹', '¥', 'AED', 'SAR'];

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.onboarded = false,
    this.appLock = false,
    this.currency = r'$',
  });

  final ThemeMode themeMode;
  final bool onboarded;
  final bool appLock;
  final String currency;

  AppSettings copyWith({ThemeMode? themeMode, bool? onboarded, bool? appLock, String? currency}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        onboarded: onboarded ?? this.onboarded,
        appLock: appLock ?? this.appLock,
        currency: currency ?? this.currency,
      );
}

class SettingsController extends Notifier<AppSettings> {
  static const _kTheme = 'theme_mode';
  static const _kOnboarded = 'onboarded';
  static const _kLock = 'app_lock';
  static const _kCurrency = 'currency';

  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  AppSettings build() {
    final p = ref.watch(prefsProvider);
    return AppSettings(
      themeMode: switch (p.getString(_kTheme)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      onboarded: p.getBool(_kOnboarded) ?? false,
      appLock: p.getBool(_kLock) ?? false,
      currency: p.getString(_kCurrency) ?? r'$',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _p.setString(_kTheme, mode.name);
  }

  Future<void> setOnboarded() async {
    state = state.copyWith(onboarded: true);
    await _p.setBool(_kOnboarded, true);
  }

  Future<void> setAppLock(bool on) async {
    state = state.copyWith(appLock: on);
    await _p.setBool(_kLock, on);
  }

  Future<void> setCurrency(String symbol) async {
    state = state.copyWith(currency: symbol);
    await _p.setString(_kCurrency, symbol);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Formats amounts with the chosen currency symbol.
class Money {
  Money(this.symbol) : _f = NumberFormat('#,##0.00', 'en_US');

  final String symbol;
  final NumberFormat _f;

  String call(double v) {
    final s = _f.format(v.abs());
    final sep = symbol.length > 1 ? ' ' : '';
    return '${v < 0 ? '-' : ''}$symbol$sep$s';
  }

  /// No decimals, for chart labels and tiles.
  String short(double v) {
    final s = NumberFormat('#,##0', 'en_US').format(v.abs().round());
    final sep = symbol.length > 1 ? ' ' : '';
    return '${v < 0 ? '-' : ''}$symbol$sep$s';
  }
}

final moneyProvider = Provider<Money>((ref) => Money(ref.watch(settingsProvider.select((s) => s.currency))));
