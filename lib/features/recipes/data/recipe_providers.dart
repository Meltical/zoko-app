import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/data/pantry_providers.dart';
import '../domain/ingredient_matcher.dart';
import '../domain/recipe.dart';
import '../domain/recipe_match.dart';
import 'recipes_repository.dart';

class RecipeCatalog {
  RecipeCatalog(this.recipes, List<Ingredient> ingredients)
    : ingredients = {for (final ingredient in ingredients) ingredient.key: ingredient},
      matcher = IngredientMatcher(ingredients);

  final List<Recipe> recipes;
  final Map<String, Ingredient> ingredients;
  final IngredientMatcher matcher;

  Recipe? bySlug(String slug) {
    for (final recipe in recipes) {
      if (recipe.slug == slug) return recipe;
    }
    return null;
  }
}

final recipeCatalogProvider = FutureProvider<RecipeCatalog>((ref) async {
  final repository = ref.watch(recipesRepositoryProvider);
  final (recipes, ingredients) = await (repository.fetchRecipes(), repository.fetchIngredients()).wait;
  return RecipeCatalog(recipes, ingredients);
});

final pantryIndexProvider = Provider<PantryIndex?>((ref) {
  final catalog = ref.watch(recipeCatalogProvider).value;
  final products = ref.watch(productsProvider).value;
  if (catalog == null || products == null) return null;
  return PantryIndex(catalog.matcher, products);
});

final recipeMatchesProvider = Provider<List<RecipeMatch>>((ref) {
  final catalog = ref.watch(recipeCatalogProvider).value;
  final index = ref.watch(pantryIndexProvider);
  if (catalog == null || index == null) return const [];
  return [for (final recipe in catalog.recipes) index.match(recipe, catalog.ingredients)];
});

final cookableRecipesProvider = Provider<List<RecipeMatch>>(
  (ref) => [
    for (final match in ref.watch(recipeMatchesProvider))
      if (match.isComplete && match.usesPantry) match,
  ]..sort(compareCookable),
);

final partialRecipesProvider = Provider<List<RecipeMatch>>(
  (ref) => [
    for (final match in ref.watch(recipeMatchesProvider))
      if (!match.isComplete && match.availableCount > 0) match,
  ]..sort(comparePartial),
);

final recipeMatchProvider = Provider.family<RecipeMatch?, String>((ref, slug) {
  for (final match in ref.watch(recipeMatchesProvider)) {
    if (match.recipe.slug == slug) return match;
  }
  return null;
});

final productRecipesProvider = Provider.family<List<RecipeMatch>, String>((ref, productName) {
  final catalog = ref.watch(recipeCatalogProvider).value;
  if (catalog == null) return const [];
  final keys = catalog.matcher.keysFor(productName);
  if (keys.isEmpty) return const [];
  return [
    for (final match in ref.watch(recipeMatchesProvider))
      if (match.recipe.ingredients.any((item) => item.keys.any(keys.contains))) match,
  ]..sort(comparePartial);
});

final productRecipeCountProvider = Provider.family<int, String>(
  (ref, productName) => ref.watch(productRecipesProvider(productName)).length,
);
