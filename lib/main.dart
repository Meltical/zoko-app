import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.isConfigured) {
    runApp(const MissingConfigApp());
    return;
  }

  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseKey);
  final preferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(allowList: PreferenceKeys.all),
  );

  runApp(ProviderScope(overrides: [preferencesProvider.overrideWithValue(preferences)], child: const ZokoApp()));
}
