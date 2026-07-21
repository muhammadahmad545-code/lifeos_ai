import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../shared/widgets/premium_card.dart';
import 'auth_state.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    final String? remembered = ref.read(settingsServiceProvider).rememberedEmail;
    if (remembered != null) {
      _emailController.text = remembered;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final authController = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      await authController.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
      );
    } else {
      await authController.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
    if (!mounted) {
      return;
    }
    if (ref.read(authControllerProvider).isAuthenticated) {
      context.go('/home');
    }
  }

  Future<void> _withSocial(Future<void> Function() action) async {
    await action();
    if (!mounted) {
      return;
    }
    if (ref.read(authControllerProvider).isAuthenticated) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    final authController = ref.read(authControllerProvider.notifier);

    ref.listen<AuthState>(authControllerProvider, (AuthState? previous, AuthState next) {
      if (next.errorMessage != null && next.errorMessage != _lastShownError) {
        _lastShownError = next.errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PremiumCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Icon(Icons.auto_awesome_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          _isSignUp ? 'Create your account' : 'Welcome back',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignUp
                              ? 'Set up LIFEOS AI to organize your entire life.'
                              : 'Sign in to continue your day inside LIFEOS AI.',
                        ),
                        const SizedBox(height: 24),
                        if (_isSignUp) ...<Widget>[
                          TextFormField(
                            controller: _displayNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(labelText: 'Display name'),
                            validator: (String? value) =>
                                (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                          validator: (String? value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          onFieldSubmitted: (_) => _submit(),
                          validator: (String? value) {
                            if (value == null || value.length < 6) {
                              return 'At least 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (!_isSignUp) ...<Widget>[
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Checkbox(
                                value: authState.rememberMe,
                                onChanged: (bool? value) => authController.toggleRememberMe(value ?? false),
                              ),
                              const Expanded(child: Text('Remember me')),
                              TextButton(
                                onPressed: () => context.push('/forgot-password'),
                                child: const Text('Forgot password?'),
                              ),
                            ],
                          ),
                        ] else
                          const SizedBox(height: 16),
                        FilledButton(
                          onPressed: authState.isLoading ? null : _submit,
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_isSignUp ? 'Create account' : 'Sign in'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: authState.isLoading
                              ? null
                              : () => setState(() => _isSignUp = !_isSignUp),
                          child: Text(
                            _isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up",
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or', style: Theme.of(context).textTheme.bodySmall),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.g_mobiledata_rounded),
                          onPressed: authState.isLoading
                              ? null
                              : () => _withSocial(authController.signInWithGoogle),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.apple),
                          onPressed: authState.isLoading
                              ? null
                              : () => _withSocial(authController.signInWithApple),
                          label: const Text('Continue with Apple'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.password_rounded),
                          onPressed: authState.isLoading ? null : () => context.push('/otp'),
                          label: const Text('Sign in with OTP'),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          icon: const Icon(Icons.fingerprint_rounded),
                          onPressed: authState.isLoading ? null : () => context.push('/biometric-login'),
                          label: const Text('Use biometrics instead'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
