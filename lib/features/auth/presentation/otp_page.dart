import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../shared/widgets/premium_card.dart';
import 'auth_state.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _isRequesting = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Enter a valid email address.', isError: true);
      return;
    }
    setState(() => _isRequesting = true);
    final String? code = await ref.read(authControllerProvider.notifier).requestOtp(email);
    setState(() {
      _isRequesting = false;
      _codeSent = code != null;
    });
    if (!mounted) {
      return;
    }
    if (code != null) {
      _showSnack('Your one-time code: $code');
    } else {
      _showSnack('Could not send a code for that email.', isError: true);
    }
  }

  Future<void> _verify() async {
    final authController = ref.read(authControllerProvider.notifier);
    await authController.signInWithOtp(
      email: _emailController.text.trim(),
      code: _codeController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (ref.read(authControllerProvider).isAuthenticated) {
      context.go('/home');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('OTP sign in')),
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
                      'Sign in with a one-time code',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text('Enter your email, request a code, then verify to sign in instantly.'),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isRequesting ? null : _requestCode,
                      child: _isRequesting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_codeSent ? 'Resend code' : 'Send code'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: 'OTP code', prefixIcon: Icon(Icons.pin_outlined)),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: authState.isLoading ? null : _verify,
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Verify & sign in'),
                    ),
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
