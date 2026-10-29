import 'package:flutter_test/flutter_test.dart';
import 'package:zoko/features/pantry/domain/quick_entry.dart';

void main() {
  final now = DateTime(2026, 10, 28);

  test('date jour/mois en fin de saisie', () {
    final entry = parseQuickEntry('yaourts 12/11', now: now);
    expect(entry.name, 'yaourts');
    expect(entry.exp, DateTime(2026, 11, 12));
  });

  test('date avec année', () {
    expect(parseQuickEntry('jambon 3/1/27', now: now).exp, DateTime(2027, 1, 3));
  });

  test('une date passée de plus de deux mois bascule sur l’année suivante', () {
    expect(parseQuickEntry('confiture 15/02', now: now).exp, DateTime(2027, 2, 15));
  });

  test('délai en jours, semaines, mois', () {
    expect(parseQuickEntry('poulet +3', now: now).exp, DateTime(2026, 10, 31));
    expect(parseQuickEntry('soupe +2s', now: now).exp, DateTime(2026, 11, 11));
    expect(parseQuickEntry('glace +3m', now: now).exp, DateTime(2027, 1, 28));
  });

  test('le passage à l’heure d’hiver ne décale pas la date', () {
    expect(parseQuickEntry('pain +1', now: DateTime(2026, 10, 24)).exp, DateTime(2026, 10, 25));
    expect(parseQuickEntry('pain +2', now: DateTime(2026, 10, 24)).exp, DateTime(2026, 10, 26));
  });

  test('date invalide : nom conservé, pas de date', () {
    final entry = parseQuickEntry('lait 31/02', now: now);
    expect(entry.name, 'lait 31/02');
    expect(entry.exp, isNull);
  });

  test('sans date', () {
    final entry = parseQuickEntry('  mozzarella ', now: now);
    expect(entry.name, 'mozzarella');
    expect(entry.exp, isNull);
  });

  test('date en toutes lettres', () {
    expect(parseQuickEntry('jambon 15 novembre', now: now), (name: 'jambon', exp: DateTime(2026, 11, 15)));
    expect(parseQuickEntry('Lait 1er déc.', now: now).exp, DateTime(2026, 12, 1));
    expect(parseQuickEntry('poulet le 3 fevrier 2027', now: now), (name: 'poulet', exp: DateTime(2027, 2, 3)));
    expect(parseQuickEntry('glace 2 juil', now: now).exp, DateTime(2027, 7, 2));
    expect(parseQuickEntry('beurre 30 juin', now: now).exp, DateTime(2027, 6, 30));
    expect(parseQuickEntry('crème 5 AOÛT 27', now: now).exp, DateTime(2027, 8, 5));
    expect(parseQuickEntry('fromage 31 novembre', now: now).exp, isNull);
  });
}
