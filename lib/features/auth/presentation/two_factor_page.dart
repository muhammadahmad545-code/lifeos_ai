import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../shared/widgets/premium_card.dart';
import '../domain/auth_user.dart';
import 'auth_state.dart';

class TwoFactorPage extends ConsumerWidget {
  const TwoFactorPage({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enabled) async {
    await ref.read(authControllerProvider.notifier).enableTwoFactor(enabled);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(enabled ? '2FA enabled for your account.' : '2FA disabled.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState authState = ref.watch(authControllerProvider);
    final AuthUser? user = authState.user;
    final bool enabled = user?.isTwoFactorEnabled ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Two-factor authentication')),
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
                    Icon(
                      enabled ? Icons.verified_user_rounded : Icons.shield_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      enabled ? '2FA is currently enabled' : 'Protect your account with 2FA',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Two-factor authentication adds a one-time code step on top of your password. '
                      'Once enabled, sensitive actions such as password resets will require an additional '
                      'verification code (123456 in local mode) before they take effect.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: user == null ? null : () => _toggle(context, ref, !enabled),
                      style: enabled
                          ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
                          : null,
                      child: Text(enabled ? 'Disable 2FA' : 'Enable 2FA'),
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
