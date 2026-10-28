import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../household/data/household_providers.dart';
import '../household/data/household_repository.dart';
import '../reminders/reminder_service.dart';
import '../updater/updater.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final household = ref.watch(householdProvider).value;
    final members = ref.watch(memberCountProvider).value;
    final reminders = ref.watch(reminderSettingsProvider);
    final version = ref.watch(currentVersionProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          if (household != null) ...[
            _SectionTitle('Foyer'),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(household.name),
              subtitle: Text(switch (members) {
                null => ' ',
                1 => '1 téléphone',
                _ => '$members téléphones',
              }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: theme.colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Text('Code pour rejoindre ce foyer', style: theme.textTheme.labelLarge),
                      SelectableText(
                        household.formattedCode,
                        style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2, fontFamily: 'monospace'),
                      ),
                      Text(
                        'Gardez-le précieusement : il permet aussi de retrouver le foyer '
                        'si vous changez de téléphone. Toute personne qui l’a peut lire et modifier le frigo.',
                        style: theme.textTheme.bodySmall,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: household.formattedCode));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copié')));
                              }
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Copier'),
                          ),
                          TextButton.icon(
                            onPressed: () => SharePlus.instance.share(
                              ShareParams(text: 'Rejoins notre frigo sur Zoko avec le code ${household.formattedCode}'),
                            ),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Partager'),
                          ),
                          TextButton.icon(
                            onPressed: () => _rotateCode(context, ref),
                            icon: const Icon(Icons.autorenew),
                            label: const Text('Nouveau code'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (ReminderService.isSupported) ...[
            _SectionTitle('Rappels'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Prévenir la veille de la péremption'),
              subtitle: Text('Chaque jour à ${reminders.hour} h, hors congélateur'),
              value: reminders.enabled,
              onChanged: (enabled) async {
                final notifier = ref.read(reminderSettingsProvider.notifier);
                if (!enabled) return notifier.disable();
                final granted = await notifier.enable();
                if (!granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Autorisez les notifications de Zoko dans les réglages du téléphone')),
                  );
                }
              },
            ),
            if (reminders.enabled)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Heure du rappel'),
                trailing: DropdownButton<int>(
                  value: reminders.hour,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final hour in [8, 12, 17, 18, 19, 20]) DropdownMenuItem(value: hour, child: Text('$hour h')),
                  ],
                  onChanged: (hour) => ref.read(reminderSettingsProvider.notifier).setHour(hour!),
                ),
              ),
          ],
          _SectionTitle('Application'),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text('Version ${version ?? '…'}'),
            subtitle: Text(Updater.isSupported ? 'Rechercher une mise à jour' : 'Mises à jour via GitHub'),
            onTap: Updater.isSupported ? () => _checkUpdate(context, ref) : null,
          ),
          if (household != null)
            ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text('Quitter le foyer', style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Ce téléphone ne verra plus le frigo'),
              onTap: () => _leave(context, ref),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    ref.invalidate(availableUpdateProvider);
    final release = await ref.read(availableUpdateProvider.future);
    if (!context.mounted) return;
    if (release == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zoko est à jour')));
    } else {
      await showUpdateDialog(context, release);
    }
  }

  Future<void> _rotateCode(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Générer un nouveau code ?',
      message: 'L’ancien code ne marchera plus. Les téléphones déjà dans le foyer ne sont pas concernés.',
      action: 'Nouveau code',
    );
    if (!confirmed) return;
    try {
      await ref.read(householdProvider.notifier).rotateCode();
    } on HouseholdException catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final members = ref.read(memberCountProvider).value ?? 1;
    final confirmed = await _confirm(
      context,
      title: 'Quitter le foyer ?',
      message: members <= 1
          ? 'Vous êtes le dernier téléphone : le foyer et tout son contenu seront supprimés définitivement.'
          : 'Vous pourrez revenir avec le code du foyer.',
      action: 'Quitter',
      destructive: true,
    );
    if (confirmed) await ref.read(householdProvider.notifier).leave();
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
