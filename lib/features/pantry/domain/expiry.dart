import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/dates.dart';

enum ExpiryLevel { expired, today, soon, week, later }

class Expiry {
  Expiry(this.date, {DateTime? now}) : daysLeft = daysBetween(now ?? today(), date);

  final DateTime date;
  final int daysLeft;

  ExpiryLevel get level => switch (daysLeft) {
    < 0 => ExpiryLevel.expired,
    0 => ExpiryLevel.today,
    <= 2 => ExpiryLevel.soon,
    <= 7 => ExpiryLevel.week,
    _ => ExpiryLevel.later,
  };

  bool get isUrgent => daysLeft <= 2;

  String get label => switch (daysLeft) {
    < -1 => 'Périmé depuis ${-daysLeft} j',
    -1 => 'Périmé depuis hier',
    0 => "Aujourd'hui",
    1 => 'Demain',
    <= 30 => 'Dans $daysLeft j',
    _ => 'Le ${DateFormat('d MMM y', 'fr').format(date)}',
  };

  String get badge => switch (daysLeft) {
    < 0 => '!',
    0 => 'J',
    <= 99 => '$daysLeft j',
    _ => '99+',
  };

  Color color(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (level) {
      ExpiryLevel.expired => dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
      ExpiryLevel.today => dark ? const Color(0xFFFFAB91) : const Color(0xFFE64A19),
      ExpiryLevel.soon => dark ? const Color(0xFFFFCC80) : const Color(0xFFEF8F00),
      ExpiryLevel.week => dark ? const Color(0xFFC5E1A5) : const Color(0xFF689F38),
      ExpiryLevel.later => dark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32),
    };
  }
}
