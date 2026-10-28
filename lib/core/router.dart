import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/household/data/household_providers.dart';
import '../features/household/presentation/welcome_page.dart';
import '../features/pantry/presentation/pantry_page.dart';
import '../features/pantry/presentation/product_detail_page.dart';
import '../features/recipes/presentation/product_recipes_page.dart';
import '../features/recipes/presentation/recipe_detail_page.dart';
import '../features/recipes/presentation/recipes_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shopping/presentation/shopping_page.dart';
import '../shared/home_shell.dart';
import '../shared/startup_page.dart';

abstract final class Routes {
  static const pantry = '/';
  static const recipes = '/recettes';
  static const shopping = '/courses';
  static const settings = '/reglages';
  static const welcome = '/bienvenue';
  static const startup = '/demarrage';

  static String product(int id) => '/produit/$id';
  static String productRecipes(int id) => '/produit/$id/recettes';
  static String recipe(String slug) => '/recette/$slug';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(householdProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.startup,
    refreshListenable: refresh,
    redirect: (context, state) {
      final household = ref.read(householdProvider);
      final location = state.matchedLocation;
      if (!household.hasValue) return location == Routes.startup ? null : Routes.startup;
      if (household.value == null) return location == Routes.welcome ? null : Routes.welcome;
      if (location == Routes.startup || location == Routes.welcome) return Routes.pantry;
      return null;
    },
    routes: [
      GoRoute(path: Routes.startup, builder: (_, _) => const StartupPage()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomePage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.pantry, builder: (_, _) => const PantryPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.recipes, builder: (_, _) => const RecipesPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.shopping, builder: (_, _) => const ShoppingPage())],
          ),
        ],
      ),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: '/produit/:id',
        builder: (_, state) => ProductDetailPage(productId: int.parse(state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'recettes',
            builder: (_, state) => ProductRecipesPage(productId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(
        path: '/recette/:slug',
        builder: (_, state) => RecipeDetailPage(slug: state.pathParameters['slug']!),
      ),
    ],
  );
});
