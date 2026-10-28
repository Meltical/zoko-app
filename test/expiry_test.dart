import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zoko/features/pantry/domain/expiry.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  final now = DateTime(2026, 10, 28);

  test('libellés', () {
    expect(Expiry(DateTime(2026, 10, 26), now: now).label, 'Périmé depuis 2 j');
    expect(Expiry(DateTime(2026, 10, 27), now: now).label, 'Périmé depuis hier');
    expect(Expiry(DateTime(2026, 10, 28), now: now).label, "Aujourd'hui");
    expect(Expiry(DateTime(2026, 10, 29), now: now).label, 'Demain');
    expect(Expiry(DateTime(2026, 11, 3), now: now).label, 'Dans 6 j');
    expect(Expiry(DateTime(2027, 2, 1), now: now).label, 'Le 1 févr. 2027');
  });

  test('niveaux d’urgence', () {
    expect(Expiry(DateTime(2026, 10, 27), now: now).level, ExpiryLevel.expired);
    expect(Expiry(DateTime(2026, 10, 30), now: now).level, ExpiryLevel.soon);
    expect(Expiry(DateTime(2026, 11, 4), now: now).level, ExpiryLevel.week);
    expect(Expiry(DateTime(2026, 11, 5), now: now).level, ExpiryLevel.later);
  });

  test('le changement d’heure ne fausse pas le décompte', () {
    expect(Expiry(DateTime(2026, 10, 26), now: DateTime(2026, 10, 24)).daysLeft, 2);
  });
}
