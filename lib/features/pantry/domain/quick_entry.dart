import '../../../core/dates.dart';

typedef QuickEntry = ({String name, DateTime? exp});

final _trailingDate = RegExp(r'\s+(\d{1,2})[/.-](\d{1,2})(?:[/.-](\d{2}|\d{4}))?\s*$');
final _trailingDelay = RegExp(r'\s+\+(\d{1,3})\s*(j|s|sem|m|mois)?\s*$', caseSensitive: false);

/// Extrait une date tapée à la fin du nom : « yaourts 12/11 », « jambon 3/12/26 »,
/// « poulet +3 » (jours), « soupe +2s » (semaines), « glace +3m » (mois).
QuickEntry parseQuickEntry(String input, {DateTime? now}) {
  final reference = now ?? today();

  final date = _trailingDate.firstMatch(input);
  if (date != null) {
    final day = int.parse(date.group(1)!);
    final month = int.parse(date.group(2)!);
    final rawYear = date.group(3);
    var year = rawYear == null
        ? reference.year
        : rawYear.length == 2
        ? 2000 + int.parse(rawYear)
        : int.parse(rawYear);
    if (month < 1 || month > 12 || day < 1 || day > DateTime(year, month + 1, 0).day) {
      return (name: input.trim(), exp: null);
    }
    if (rawYear == null && DateTime(year, month, day).isBefore(addDays(reference, -60))) {
      year++;
    }
    return (name: input.substring(0, date.start).trim(), exp: DateTime(year, month, day));
  }

  final delay = _trailingDelay.firstMatch(input);
  if (delay != null) {
    final amount = int.parse(delay.group(1)!);
    final unit = (delay.group(2) ?? 'j').toLowerCase();
    final exp = switch (unit) {
      's' || 'sem' => addDays(reference, 7 * amount),
      'm' || 'mois' => addMonths(reference, amount),
      _ => addDays(reference, amount),
    };
    return (name: input.substring(0, delay.start).trim(), exp: exp);
  }

  return (name: input.trim(), exp: null);
}
