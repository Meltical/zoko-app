import '../../../core/text.dart';
import 'recipe.dart';

typedef _Alias = ({String key, List<String> tokens});

/// Relie un nom de produit libre (« Pavé de saumon ») aux clés d'ingrédients
/// des recettes. Seule l'expression la plus précise compte : « pomme de terre »
/// ne compte pas comme « pomme », ni « pain de mie » comme « pain ».
class IngredientMatcher {
  IngredientMatcher(Iterable<Ingredient> ingredients)
    : _aliases = [
        for (final ingredient in ingredients)
          for (final alias in {ingredient.name, ...ingredient.aliases})
            (key: ingredient.key, tokens: searchTokens(alias)),
      ]..removeWhere((alias) => alias.tokens.isEmpty);

  final List<_Alias> _aliases;
  final _cache = <String, Set<String>>{};

  Set<String> keysFor(String productName) => _cache.putIfAbsent(productName, () {
    final tokens = searchTokens(productName);
    final hits = [
      for (final alias in _aliases)
        if (containsSequence(tokens, alias.tokens)) alias,
    ];
    return {
      for (final hit in hits)
        if (!hits.any(
          (other) =>
              other.key != hit.key &&
              other.tokens.length > hit.tokens.length &&
              containsSequence(other.tokens, hit.tokens),
        ))
          hit.key,
    };
  });
}
