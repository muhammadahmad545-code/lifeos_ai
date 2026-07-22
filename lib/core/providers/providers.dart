import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/router.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/data/datasources/local_auth_remote_data_source.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/services/biometric_service.dart';
import '../../features/auth/services/local_auth_biometric_service.dart';
import '../../features/auth/services/secure_session_store.dart';
import '../../features/auth/services/session_store.dart';
import '../../features/auth/services/social_auth_service.dart';
import '../../features/tasks/data/task_template_store.dart';
import '../services/local_notification_service.dart';
import '../services/ocr_service.dart';
import '../services/settings_service.dart';
import '../services/weather_service.dart';
import 'database_provider.dart';

final settingsBoxProvider = Provider<Box<dynamic>>((ref) {
  return Hive.box<dynamic>(SettingsService.boxName);
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(settingsBoxProvider));
});

final taskTemplateStoreProvider = Provider<TaskTemplateStore>((ref) {
  return TaskTemplateStore(Hive.box<dynamic>(TaskTemplateStore.boxName));
});

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(settingsServiceProvider));
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._settings) : super(_settings.themeMode);

  final SettingsService _settings;

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settings.setThemeMode(mode);
    state = mode;
  }
}

final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SecureSessionStore();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return LocalAuthBiometricService();
});

final socialAuthServiceProvider = Provider<SocialAuthService>((ref) {
  return SocialAuthService();
});

final weatherServiceProvider = Provider<WeatherService>((ref) => WeatherService());

final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());

final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

final weatherProvider = FutureProvider.autoDispose<WeatherSnapshot>((ref) async {
  final String city = ref.watch(settingsServiceProvider).weatherCity;
  return ref.watch(weatherServiceProvider).fetchForCity(city);
});

final localAuthRemoteDataSourceProvider = Provider<LocalAuthRemoteDataSource>((ref) {
  return LocalAuthRemoteDataSource(ref.watch(appDatabaseProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    localAuth: ref.watch(localAuthRemoteDataSourceProvider),
    sessionStore: ref.watch(sessionStoreProvider),
    biometricService: ref.watch(biometricServiceProvider),
    settingsService: ref.watch(settingsServiceProvider),
    socialAuthService: ref.watch(socialAuthServiceProvider),
  );
});

final authSessionProvider = StreamProvider<AuthUser?>((ref) {
  final AuthRepository repository = ref.watch(authRepositoryProvider);
  return repository.watchSession();
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(settingsServiceProvider),
  );
});

final appRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter(ref);
});
