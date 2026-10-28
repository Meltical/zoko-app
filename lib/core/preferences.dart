import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesProvider = Provider<SharedPreferencesWithCache>(
  (ref) => throw UnimplementedError('preferencesProvider doit être surchargé dans main()'),
);

abstract final class PreferenceKeys {
  static const lastLocation = 'last_location';
  static const remindersEnabled = 'reminders_enabled';
  static const reminderHour = 'reminder_hour';

  static const all = {lastLocation, remindersEnabled, reminderHour};
}
