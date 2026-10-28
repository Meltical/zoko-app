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
    final membership = ref.watch(householdProvider).value;
    final isAdmin = ref.watch(isAdminProvider);
    final code = ref.watch(joinCodeProvider).value;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final reminders = ref.watch(reminderSettingsProvider);
    final version = ref.watch(currentVersionProvider).value;
    final pending = [
      for (final member in members)
        if (!member.approved) member,
    ];
    final approved = [
      for (final member in members)
        if (member.approved) member,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          if (membership != null) ...[
            _SectionTitle('Foyer « ${membership.householdName} »'),
            if (isAdmin && pending.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  pending.length == 1 ? '1 demande en attente' : '${pending.length} demandes en attente',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
              for (final member in pending)
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: Text(member.label),
                  subtitle: const Text('Demande à rejoindre le foyer'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Refuser',
                        onPressed: () => _run(context, () => ref.read(membersProvider.notifier).remove(member)),
                        icon: const Icon(Icons.close),
                      ),
                      IconButton.filled(
                        tooltip: 'Approuver',
                        onPressed: () => _run(context, () => ref.read(membersProvider.notifier).approve(member)),
                        icon: const Icon(Icons.check),
                      ),
                    ],
                  ),
                ),
            ],
            for (final member in approved)
              ListTile(
                leading: Icon(member.isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline),
                title: Text(member.isMe ? '${member.label} (ce téléphone)' : member.label),
                subtitle: Text(member.isAdmin ? 'Admin' : 'Membre'),
                trailing: isAdmin && !member.isMe
                    ? IconButton(
                        tooltip: 'Retirer du foyer',
                        onPressed: () => _removeMember(context, ref, member),
                        icon: const Icon(Icons.person_remove_outlined),
                      )
                    : null,
              ),
            if (code != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Text('Code pour rejoindre le foyer', style: theme.textTheme.labelLarge),
                        SelectableText(
                          formatJoinCode(code),
                          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2, fontFamily: 'monospace'),
                        ),
                        Text(
                          'Un nouveau téléphone qui saisit ce code doit encore être approuvé par un admin. '
                          'Gardez-le : il sert aussi à retrouver le foyer après un changement de téléphone.',
                          style: theme.textTheme.bodySmall,
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: formatJoinCode(code)));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(content: Text('Code copié')));
                                }
                              },
                              icon: const Icon(Icons.copy),
                              label: const Text('Copier'),
                            ),
                            TextButton.icon(
                              onPressed: () => SharePlus.instance.share(
                                ShareParams(
                                  text:
                                      'Rejoins notre frigo « ${membership.householdName} » sur Zoko : ${inviteLink(code)}',
                                ),
                              ),
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Partager l’invitation'),
                            ),
                            if (isAdmin)
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
            const _SectionTitle('Rappels'),
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
          const _SectionTitle('Application'),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text('Version ${version ?? '…'}'),
            subtitle: Text(Updater.isSupported ? 'Rechercher une mise à jour' : 'Mises à jour via GitHub'),
            onTap: Updater.isSupported ? () => _checkUpdate(context, ref) : null,
          ),
          if (membership != null)
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

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
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

  Future<void> _removeMember(BuildContext context, WidgetRef ref, Member member) async {
    final confirmed = await _confirm(
      context,
      title: 'Retirer ${member.label} ?',
      message: 'Ce téléphone ne verra plus le frigo. Il pourra redemander à rejoindre avec le code.',
      action: 'Retirer',
      destructive: true,
    );
    if (confirmed && context.mounted) await _run(context, () => ref.read(membersProvider.notifier).remove(member));
  }

  Future<void> _rotateCode(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Générer un nouveau code ?',
      message: 'L’ancien code ne marchera plus. Les téléphones déjà dans le foyer ne sont pas concernés.',
      action: 'Nouveau code',
    );
    if (confirmed && context.mounted) await _run(context, () => ref.read(membersProvider.notifier).rotateCode());
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Quitter le foyer ?',
      message: 'Le frigo reste intact pour les autres. Vous pourrez revenir avec le code, après approbation.',
      action: 'Quitter',
      destructive: true,
    );
    if (confirmed && context.mounted) await _run(context, () => ref.read(householdProvider.notifier).leave());
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
