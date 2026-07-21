import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings_service.dart';
import '../domain/auth_repository.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._settings) : super(const AuthState());

  final AuthRepository _repository;
  final SettingsService _settings;

  Future<void> signInWithEmail({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.signInWithEmail(email: email, password: password);
      if (state.rememberMe) {
        await _settings.setRememberedEmail(email);
      } else {
        await _settings.setRememberedEmail(null);
      }
      state = state.copyWith(user: user, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _settings.setRememberedEmail(email);
      state = state.copyWith(user: user, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.signInWithGoogle();
      state = state.copyWith(user: user, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: 'Google sign-in failed.');
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.signInWithApple();
      state = state.copyWith(user: user, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: 'Apple sign-in failed.');
    }
  }

  Future<void> signInWithOtp({required String email, required String code}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.signInWithOtp(email: email, code: code);
      state = state.copyWith(user: user, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<String?> requestOtp(String email) async {
    try {
      return await _repository.requestOtp(email: email);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString().replaceFirst('Bad state: ', ''));
      return null;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.sendPasswordReset(email: email);
      state = state.copyWith(isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> resetPassword({required String email, required String newPassword}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.resetPassword(email: email, newPassword: newPassword);
      state = state.copyWith(isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState();
  }

  Future<void> enableTwoFactor(bool enabled) async {
    final user = await _repository.enableTwoFactor(enabled: enabled);
    state = state.copyWith(user: user);
  }

  Future<void> enableBiometricLogin(bool enabled) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.enableBiometricLogin(enabled: enabled);
      state = state.copyWith(user: user, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> updateProfile({required String displayName}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.updateProfile(displayName: displayName);
      state = state.copyWith(user: user, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<bool> unlockWithBiometrics() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final unlocked = await _repository.unlockWithBiometrics();
      state = state.copyWith(user: unlocked, isLoading: false);
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Bad state: ', ''));
      return false;
    }
  }

  void toggleRememberMe(bool value) {
    state = state.copyWith(rememberMe: value);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
