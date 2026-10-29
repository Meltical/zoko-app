import '../../../core/dates.dart';
import '../../../core/text.dart';

typedef QuickEntry = ({String name, DateTime? exp});

final _trailingDate = RegExp(r'\s+(\d{1,2})[/.-](\d{1,2})(?:[/.-](\d{2}|\d{4}))?\s*$');
final _trailingWrittenDate = RegExp(
  r'\s+(?:le\s+)?(\d{1,2})(?:er)?\s+'
  r'(janv(?:ier)?|f[ée]vr?(?:ier)?|mars|avr(?:il)?|mai|juin|juil(?:let)?|ao[uû]t?|sept?(?:embre)?|oct(?:obre)?|nov(?:embre)?|d[ée]c(?:embre)?)'
  r'\.?(?:\s+(\d{4}|\d{2}))?\s*$',
  caseSensitive: false,
  unicode: true,
);
final _trailingDelay = RegExp(r'\s+\+(\d{1,3})\s*(j|s|sem|m|mois)?\s*$', caseSensitive: false);

const _monthPrefixes = {
  'jan': 1,
  'fev': 2,
  'mar': 3,
  'avr': 4,
  'mai': 5,
  'juin': 6,
  'juil': 7,
  'aou': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// Extrait une date tapée à la fin du nom : « yaourts 12/11 », « jambon 15 novembre »,
/// « lait 1er déc. 2027 », « poulet +3 » (jours), « soupe +2s » (semaines), « glace +3m » (mois).
QuickEntry parseQuickEntry(String input, {DateTime? now}) {
  final reference = now ?? today();

  final numeric = _trailingDate.firstMatch(input);
  if (numeric != null) {
    return _withDate(
      input,
      numeric.start,
      int.parse(numeric.group(1)!),
      int.parse(numeric.group(2)!),
      numeric.group(3),
      reference,
    );
  }

  final written = _trailingWrittenDate.firstMatch(input);
  if (written != null) {
    final month = _monthNumber(written.group(2)!);
    if (month != null) {
      return _withDate(input, written.start, int.parse(written.group(1)!), month, written.group(3), reference);
    }
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

QuickEntry _withDate(String input, int start, int day, int month, String? rawYear, DateTime reference) {
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
  return (name: input.substring(0, start).trim(), exp: DateTime(year, month, day));
}

int? _monthNumber(String word) {
  final folded = normalizeText(word);
  if (folded.startsWith('juil')) return 7;
  if (folded.startsWith('juin')) return 6;
  for (final MapEntry(key: prefix, value: month) in _monthPrefixes.entries) {
    if (folded.startsWith(prefix)) return month;
  }
  return null;
}
