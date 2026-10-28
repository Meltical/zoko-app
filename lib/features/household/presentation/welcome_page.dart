import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/household_providers.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final _code = TextEditingController();
  bool _joining = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(householdProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Icon(Icons.kitchen, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Zoko', textAlign: TextAlign.center, style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Ce qu’il y a dans le frigo, quand ça périme, et quoi cuisiner avec.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
            if (!_joining) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _busy ? null : () => _run(() => notifier.create('Maison')),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Créer mon foyer'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _busy ? null : () => setState(() => _joining = true),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Rejoindre avec un code'),
              ),
              const SizedBox(height: 16),
              Text(
                'Pas de compte ni d’e-mail : le foyer se partage avec un code, '
                'visible dans les réglages de l’app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ] else ...[
              TextField(
                controller: _code,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _run(() => notifier.join(_code.text)),
                decoration: const InputDecoration(labelText: 'Code du foyer', hintText: 'XXXX-XXXX-XXXX'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _busy ? null : () => _run(() => notifier.join(_code.text)),
                child: const Text('Rejoindre'),
              ),
              TextButton(onPressed: _busy ? null : () => setState(() => _joining = false), child: const Text('Retour')),
            ],
            if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
