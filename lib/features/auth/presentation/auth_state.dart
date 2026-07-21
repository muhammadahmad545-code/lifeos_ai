import '../domain/auth_user.dart';

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.rememberMe = true,
    this.errorMessage,
  });

  final AuthUser? user;
  final bool isLoading;
  final bool rememberMe;
  final String? errorMessage;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool? isLoading,
    bool? rememberMe,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      rememberMe: rememberMe ?? this.rememberMe,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}