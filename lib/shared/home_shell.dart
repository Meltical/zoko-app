import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/recipes/data/recipe_providers.dart';
import '../features/shopping/data/shopping_providers.dart';
import '../features/updater/updater.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  bool _updateOffered = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(availableUpdateProvider, (_, next) {
      final release = next.value;
      if (release == null || _updateOffered) return;
      _updateOffered = true;
      showUpdateDialog(context, release);
    });
    final cookable = ref.watch(cookableRecipesProvider).length;
    final shopping = ref.watch(pendingShoppingCountProvider);
    final shell = widget.shell;

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Frigo',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: cookable,
              isLabelVisible: cookable > 0,
              child: const Icon(Icons.restaurant_menu_outlined),
            ),
            selectedIcon: Badge.count(
              count: cookable,
              isLabelVisible: cookable > 0,
              child: const Icon(Icons.restaurant_menu),
            ),
            label: 'Que cuisiner ?',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: shopping,
              isLabelVisible: shopping > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge.count(
              count: shopping,
              isLabelVisible: shopping > 0,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Courses',
          ),
        ],
      ),
    );
  }
}
