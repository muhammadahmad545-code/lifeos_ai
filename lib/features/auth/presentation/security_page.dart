import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../shared/widgets/premium_card.dart';
import '../domain/auth_user.dart';
import 'auth_state.dart';

class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, bool value) async {
    await ref.read(authControllerProvider.notifier).enableBiometricLogin(value);
    if (!context.mounted) {
      return;
    }
    final String? error = ref.read(authControllerProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? (value ? 'Biometric login enabled.' : 'Biometric login disabled.')),
        backgroundColor: error != null ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState authState = ref.watch(authControllerProvider);
    final AuthUser? user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Account security')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Security settings'),
                SizedBox(height: 8),
                Text('Manage sign-in methods, 2FA, and biometric access.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              title: const Text('Two-factor authentication'),
              subtitle: const Text('Required for sensitive actions'),
              value: user?.isTwoFactorEnabled ?? false,
              onChanged: user == null ? null : (bool value) => context.push('/two-factor'),
              secondary: const Icon(Icons.verified_user_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Biometric login'),
              subtitle: const Text('Face ID, Touch ID, fingerprint'),
              value: user?.isBiometricEnabled ?? false,
              onChanged: user == null || authState.isLoading
                  ? null
                  : (bool value) => _toggleBiometric(context, ref, value),
              secondary: const Icon(Icons.fingerprint_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Edit profile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile'),
            ),
          ),
        ],
      ),
    );
  }
}
