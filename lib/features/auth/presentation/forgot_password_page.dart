import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../shared/widgets/premium_card.dart';
import 'auth_state.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  bool _codeRequested = false;
  bool _isRequesting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Enter a valid email address.', isError: true);
      return;
    }
    setState(() => _isRequesting = true);
    final String? code = await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
    setState(() {
      _isRequesting = false;
      if (code != null) {
        _codeRequested = true;
      }
    });
    if (!mounted) {
      return;
    }
    if (code != null && code.isNotEmpty) {
      _showSnack('Your reset code: $code');
    } else if (code != null) {
      _showSnack('Password reset email sent. Check your inbox.');
    } else {
      final String? error = ref.read(authControllerProvider).errorMessage;
      _showSnack(error ?? 'Could not send reset code.', isError: true);
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.length < 6) {
      _showSnack('New password must be at least 6 characters.', isError: true);
      return;
    }
    final authController = ref.read(authControllerProvider.notifier);
    await authController.resetPassword(
      email: _emailController.text.trim(),
      newPassword: _newPasswordController.text,
      code: _codeController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    final String? error = ref.read(authControllerProvider).errorMessage;
    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }
    _showSnack('Password updated. Sign in with your new password.');
    if (mounted) {
      context.go('/login');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: PremiumCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      _codeRequested ? 'Enter your reset code' : 'Forgot your password?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _codeRequested
                          ? 'We sent a 6-digit code to ${_emailController.text.trim()}. Enter it below with your new password.'
                          : 'Enter the email linked to your account and we will send a reset code.',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      enabled: !_codeRequested,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                    ),
                    if (!_codeRequested) ...<Widget>[
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isRequesting ? null : _requestReset,
                        child: _isRequesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Send reset code'),
                      ),
                    ] else ...<Widget>[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: 'Reset code', prefixIcon: Icon(Icons.pin_outlined)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_outline)),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: authState.isLoading ? null : _resetPassword,
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Reset password'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _codeRequested = false),
                        child: const Text('Use a different email'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
