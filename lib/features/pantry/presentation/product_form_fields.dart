import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/dates.dart';
import '../domain/product.dart';

typedef DelayOption = ({String label, DateTime Function(DateTime from) apply});

List<DelayOption> delayOptions(StorageLocation location) => switch (location) {
  StorageLocation.fridge => [
    (label: '2 j', apply: (from) => addDays(from, 2)),
    (label: '4 j', apply: (from) => addDays(from, 4)),
    (label: '1 sem.', apply: (from) => addDays(from, 7)),
    (label: '2 sem.', apply: (from) => addDays(from, 14)),
    (label: '1 mois', apply: (from) => addMonths(from, 1)),
  ],
  StorageLocation.freezer || StorageLocation.pantry => [
    (label: '1 mois', apply: (from) => addMonths(from, 1)),
    (label: '3 mois', apply: (from) => addMonths(from, 3)),
    (label: '6 mois', apply: (from) => addMonths(from, 6)),
    (label: '1 an', apply: (from) => addMonths(from, 12)),
  ],
};

class ExpiryPicker extends StatelessWidget {
  const ExpiryPicker({
    super.key,
    required this.value,
    required this.location,
    required this.onChanged,
    this.suggestedDays,
    this.label = 'Périme le',
  });

  final DateTime? value;
  final StorageLocation location;
  final ValueChanged<DateTime> onChanged;
  final int? suggestedDays;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = today();
    final suggested = suggestedDays == null ? null : addDays(now, suggestedDays!);
    final options = delayOptions(location);
    final matchesOption = options.any((option) => option.apply(now) == value) || value == suggested;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const Spacer(),
            Text(
              value == null ? 'à choisir' : DateFormat('EEEE d MMMM', 'fr').format(value!),
              style: theme.textTheme.titleSmall?.copyWith(
                color: value == null ? theme.colorScheme.error : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (suggested != null)
              ChoiceChip(
                avatar: const Icon(Icons.history, size: 18),
                label: Text('${_formatDays(suggestedDays!)} · habituel'),
                selected: value == suggested,
                onSelected: (_) => onChanged(suggested),
              ),
            for (final option in options)
              if (option.apply(now) != suggested)
                ChoiceChip(
                  label: Text(option.label),
                  selected: value == option.apply(now),
                  onSelected: (_) => onChanged(option.apply(now)),
                ),
            ChoiceChip(
              avatar: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(value != null && !matchesOption ? DateFormat('d MMM', 'fr').format(value!) : 'Autre'),
              selected: value != null && !matchesOption,
              onSelected: (_) => _pickDate(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = today();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? addDays(now, 7),
      firstDate: addDays(now, -365),
      lastDate: addMonths(now, 60),
      helpText: 'Date de péremption',
    );
    if (picked != null) onChanged(dateOnly(picked));
  }

  static String _formatDays(int days) => switch (days) {
    0 => 'aujourd’hui',
    1 => '1 j',
    _ when days % 30 == 0 && days >= 30 => '${days ~/ 30} mois',
    _ when days % 7 == 0 && days >= 14 => '${days ~/ 7} sem.',
    _ => '$days j',
  };
}

class LocationSelector extends StatelessWidget {
  const LocationSelector({super.key, required this.value, required this.onChanged});

  final StorageLocation value;
  final ValueChanged<StorageLocation> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<StorageLocation>(
    showSelectedIcon: false,
    style: SegmentedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.padded,
    ),
    segments: [
      for (final location in StorageLocation.values)
        ButtonSegment(
          value: location,
          label: Text(location.label, maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
        ),
    ],
    selected: {value},
    onSelectionChanged: (selection) => onChanged(selection.single),
  );
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.outlined(
        tooltip: 'Retirer une unité',
        onPressed: value > 1 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove),
      ),
      SizedBox(
        width: 32,
        child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      ),
      IconButton.outlined(
        tooltip: 'Ajouter une unité',
        onPressed: value < 99 ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add),
      ),
    ],
  );
}
