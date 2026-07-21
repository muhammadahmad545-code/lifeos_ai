import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../shared/widgets/premium_card.dart';
import '../domain/auth_user.dart';
import 'auth_state.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Display name cannot be empty.'), backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }
    await ref.read(authControllerProvider.notifier).updateProfile(displayName: name);
    if (!mounted) {
      return;
    }
    final String? error = ref.read(authControllerProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Profile updated.'),
        backgroundColor: error != null ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    final AuthUser? user = authState.user;

    if (!_initialized && user != null) {
      _nameController.text = user.displayName;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              PremiumCard(
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 32,
                      child: Text(
                        (user?.displayName.isNotEmpty ?? false) ? user!.displayName[0].toUpperCase() : '?',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(user?.displayName ?? 'Unknown', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: false,
                controller: TextEditingController(text: user?.email ?? ''),
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: authState.isLoading ? null : _save,
                child: authState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
