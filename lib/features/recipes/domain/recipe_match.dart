import 'dart:math';

import '../../pantry/domain/product.dart';
import 'ingredient_matcher.dart';
import 'recipe.dart';

enum IngredientStatus { available, missing, staple, optionalMissing }

class IngredientMatch {
  const IngredientMatch(this.ingredient, this.status, this.products, this.name);

  final RecipeIngredient ingredient;
  final IngredientStatus status;
  final List<Product> products;
  final String name;
}

class RecipeMatch {
  RecipeMatch(this.recipe, this.ingredients);

  final Recipe recipe;
  final List<IngredientMatch> ingredients;

  late final List<IngredientMatch> missing = [
    for (final item in ingredients)
      if (item.status == IngredientStatus.missing) item,
  ];

  late final int requiredCount = ingredients
      .where(
        (item) =>
            item.status == IngredientStatus.available && !item.ingredient.optional ||
            item.status == IngredientStatus.missing,
      )
      .length;

  late final List<Product> usedProducts = {for (final item in ingredients) ...item.products}.toList();

  bool get isComplete => missing.isEmpty;

  bool get usesPantry => usedProducts.isNotEmpty;

  int get availableCount => requiredCount - missing.length;

  int? get urgentDaysLeft => usedProducts.isEmpty ? null : usedProducts.map((p) => p.expiry.daysLeft).reduce(min);

  List<Product> get urgentProducts => [
    for (final product in usedProducts)
      if (product.expiry.isUrgent) product,
  ];
}

class PantryIndex {
  PantryIndex(this.matcher, List<Product> products) {
    for (final product in products) {
      for (final key in matcher.keysFor(product.name)) {
        _byKey.putIfAbsent(key, () => []).add(product);
      }
    }
  }

  final IngredientMatcher matcher;
  final _byKey = <String, List<Product>>{};

  List<Product> productsFor(RecipeIngredient ingredient) =>
      {for (final key in ingredient.keys) ...?_byKey[key]}.toList();

  RecipeMatch match(Recipe recipe, Map<String, Ingredient> catalog) =>
      RecipeMatch(recipe, [for (final item in recipe.ingredients) _matchIngredient(item, catalog)]);

  IngredientMatch _matchIngredient(RecipeIngredient item, Map<String, Ingredient> catalog) {
    final products = productsFor(item);
    final IngredientStatus status;
    if (products.isNotEmpty) {
      status = IngredientStatus.available;
    } else if (catalog[item.key]?.staple ?? false) {
      status = IngredientStatus.staple;
    } else if (item.optional) {
      status = IngredientStatus.optionalMissing;
    } else {
      status = IngredientStatus.missing;
    }
    return IngredientMatch(item, status, products, catalog[item.key]?.name ?? item.label);
  }
}

int compareCookable(RecipeMatch a, RecipeMatch b) => _compareChain([
  () => (a.urgentDaysLeft ?? 999).clamp(-1, 999).compareTo((b.urgentDaysLeft ?? 999).clamp(-1, 999)),
  () => b.usedProducts.length.compareTo(a.usedProducts.length),
  () => a.recipe.title.compareTo(b.recipe.title),
]);

int comparePartial(RecipeMatch a, RecipeMatch b) => _compareChain([
  () => a.missing.length.compareTo(b.missing.length),
  () => (a.urgentDaysLeft ?? 999).clamp(-1, 999).compareTo((b.urgentDaysLeft ?? 999).clamp(-1, 999)),
  () => b.availableCount.compareTo(a.availableCount),
  () => a.recipe.title.compareTo(b.recipe.title),
]);

int _compareChain(List<int Function()> comparators) {
  for (final compare in comparators) {
    final result = compare();
    if (result != 0) return result;
  }
  return 0;
}
