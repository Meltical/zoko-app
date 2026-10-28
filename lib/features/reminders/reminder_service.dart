import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/dates.dart';
import '../../core/preferences.dart';
import '../pantry/data/pantry_providers.dart';
import '../pantry/domain/product.dart';

const _maxScheduled = 40;

final reminderSettingsProvider = NotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
  ReminderSettingsNotifier.new,
);

final reminderServiceProvider = Provider<ReminderService>((ref) => ReminderService());

/// Replanifie les rappels à chaque changement du frigo ou des réglages.
final reminderSchedulerProvider = Provider<void>((ref) {
  final settings = ref.watch(reminderSettingsProvider);
  final products = ref.watch(productsProvider).value;
  if (products == null) return;
  ref.read(reminderServiceProvider).reschedule(products, settings);
});

class ReminderSettings {
  const ReminderSettings({required this.enabled, required this.hour});

  final bool enabled;
  final int hour;
}

class ReminderSettingsNotifier extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() {
    final preferences = ref.watch(preferencesProvider);
    return ReminderSettings(
      enabled: preferences.getBool(PreferenceKeys.remindersEnabled) ?? false,
      hour: preferences.getInt(PreferenceKeys.reminderHour) ?? 18,
    );
  }

  Future<bool> enable() async {
    final granted = await ref.read(reminderServiceProvider).requestPermission();
    await _save(enabled: granted, hour: state.hour);
    return granted;
  }

  Future<void> disable() => _save(enabled: false, hour: state.hour);

  Future<void> setHour(int hour) => _save(enabled: state.enabled, hour: hour);

  Future<void> _save({required bool enabled, required int hour}) async {
    final preferences = ref.read(preferencesProvider);
    await preferences.setBool(PreferenceKeys.remindersEnabled, enabled);
    await preferences.setInt(PreferenceKeys.reminderHour, hour);
    state = ReminderSettings(enabled: enabled, hour: hour);
  }
}

class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;
  Future<void> _queue = Future.value();

  static bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _initialize() => _initialization ??= () async {
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
  }

  Future<void> reschedule(List<Product> products, ReminderSettings settings) =>
      _queue = _queue.then((_) => _reschedule(products, settings)).catchError((Object error) {
        debugPrint('Rappels non planifiés : $error');
      });

  Future<void> _reschedule(List<Product> products, ReminderSettings settings) async {
    if (!isSupported) return;
    await _initialize();
    await _plugin.cancelAllPendingNotifications();
    if (!settings.enabled) return;

    final byDay = <DateTime, List<Product>>{};
    for (final product in products) {
      if (product.location == StorageLocation.freezer) continue;
      byDay.putIfAbsent(product.exp, () => []).add(product);
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = 0;
    for (final MapEntry(key: exp, value: expiring)
        in (byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
      final dayBefore = addDays(exp, -1);
      final at = tz.TZDateTime(tz.local, dayBefore.year, dayBefore.month, dayBefore.day, settings.hour);
      if (at.isBefore(now)) continue;
      if (scheduled++ >= _maxScheduled) break;
      await _plugin.zonedSchedule(
        id: exp.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay,
        scheduledDate: at,
        title: expiring.length == 1
            ? '${expiring.single.name} périme demain'
            : '${expiring.length} produits périment demain',
        body: expiring.length == 1
            ? 'Une idée de recette vous attend dans Zoko.'
            : expiring.map((product) => product.name).join(', '),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiry',
            'Péremption',
            channelDescription: 'Rappel la veille de la date de péremption',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
