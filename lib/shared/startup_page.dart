import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/household/data/household_providers.dart';
import 'async_views.dart';

class StartupPage extends ConsumerWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(householdProvider);
    return Scaffold(
      body: household.hasError
          ? ErrorView(error: household.error!, onRetry: () => ref.invalidate(householdProvider))
          : const LoadingView(),
    );
  }
}
