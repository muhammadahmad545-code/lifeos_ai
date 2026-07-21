import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../shared/widgets/premium_card.dart';
import 'auth_state.dart';

class BiometricLoginPage extends ConsumerStatefulWidget {
  const BiometricLoginPage({super.key});

  @override
  ConsumerState<BiometricLoginPage> createState() => _BiometricLoginPageState();
}

class _BiometricLoginPageState extends ConsumerState<BiometricLoginPage> {
  Future<void> _unlock() async {
    final bool success = await ref.read(authControllerProvider.notifier).unlockWithBiometrics();
    if (!mounted) {
      return;
    }
    if (success) {
      context.go('/home');
      return;
    }
    final String? error = ref.read(authControllerProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Biometric unlock failed.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Biometric login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PremiumCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(Icons.fingerprint_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Unlock with biometrics',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use Face ID, Touch ID, or your fingerprint to unlock the account you previously signed in with. '
                    'Biometric login must be enabled first from Security settings.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.fingerprint_rounded),
                    onPressed: authState.isLoading ? null : _unlock,
                    label: authState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Unlock with biometrics'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Use email & password instead'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
