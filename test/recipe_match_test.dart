import 'package:flutter_test/flutter_test.dart';
import 'package:zoko/features/pantry/domain/product.dart';
import 'package:zoko/features/recipes/domain/ingredient_matcher.dart';
import 'package:zoko/features/recipes/domain/recipe.dart';
import 'package:zoko/features/recipes/domain/recipe_match.dart';
import 'package:zoko/features/updater/updater.dart';

Product product(int id, String name, int days) {
  final now = DateTime.now();
  return Product(
    id: id,
    name: name,
    exp: DateTime(now.year, now.month, now.day + days),
    quantity: 1,
    location: StorageLocation.fridge,
    createdAt: now,
  );
}

void main() {
  const ingredients = [
    Ingredient(key: 'saumon', name: 'Saumon', aliases: ['saumon'], staple: false),
    Ingredient(key: 'creme', name: 'Crème', aliases: ['crème fraîche'], staple: false),
    Ingredient(key: 'citron', name: 'Citron', aliases: ['citron'], staple: false),
    Ingredient(key: 'pates', name: 'Pâtes', aliases: ['tagliatelle'], staple: true),
  ];
  final catalog = {for (final ingredient in ingredients) ingredient.key: ingredient};
  const tagliatelles = Recipe(
    slug: 'tagliatelles',
    title: 'Tagliatelles au saumon',
    ingredients: [
      RecipeIngredient(key: 'pates', label: '400 g de tagliatelles'),
      RecipeIngredient(key: 'saumon', label: '2 pavés de saumon'),
      RecipeIngredient(key: 'creme', label: '25 cl de crème'),
      RecipeIngredient(key: 'citron', label: '½ citron', optional: true),
    ],
    steps: ['Cuire.'],
  );

  test('réalisable : placard et facultatif ne bloquent pas', () {
    final index = PantryIndex(IngredientMatcher(ingredients), [
      product(1, 'Pavé de saumon', 6),
      product(2, 'Crème fraîche', 0),
    ]);
    final match = index.match(tagliatelles, catalog);
    expect(match.isComplete, isTrue);
    expect(match.usedProducts.map((p) => p.id), unorderedEquals([1, 2]));
    expect(match.urgentDaysLeft, 0);
  });

  test('partielle : liste ce qui manque', () {
    final index = PantryIndex(IngredientMatcher(ingredients), [product(1, 'Pavé de saumon', 6)]);
    final match = index.match(tagliatelles, catalog);
    expect(match.isComplete, isFalse);
    expect(match.missing.map((item) => item.name), ['Crème']);
    expect(match.availableCount, 1);
  });

  test('comparaison de versions', () {
    expect(compareVersions('v2.0.1', '2.0.0'), 1);
    expect(compareVersions('2.0.0', 'v2.0.0'), 0);
    expect(compareVersions('2.1.0', '2.10.0'), -1);
    expect(compareVersions('v2.0.0+5', '2.0.0'), 0);
  });
}
