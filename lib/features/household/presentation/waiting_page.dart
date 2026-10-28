import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/household_providers.dart';

class WaitingPage extends ConsumerWidget {
  const WaitingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final membership = ref.watch(householdProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                'Demande envoyée à « ${membership?.householdName ?? 'votre foyer'} »',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Un admin du foyer doit approuver ce téléphone depuis Réglages → Membres. '
                'L’app s’ouvrira toute seule ensuite.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              const SizedBox(width: 160, child: LinearProgressIndicator()),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => ref.read(householdProvider.notifier).leave(),
                child: const Text('Annuler la demande'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
