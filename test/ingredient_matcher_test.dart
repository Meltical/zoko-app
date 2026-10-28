import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoko/features/recipes/domain/ingredient_matcher.dart';
import 'package:zoko/features/recipes/domain/recipe.dart';

void main() {
  final ingredients = (jsonDecode(File('supabase/data/ingredients.json').readAsStringSync()) as List)
      .map((json) => Ingredient.fromJson(json as Map<String, dynamic>))
      .toList();
  final matcher = IngredientMatcher(ingredients);

  final cases = {
    'Pavé de saumon': {'saumon'},
    'pain de mie ': {'pain_de_mie'},
    'Filet de poulet': {'poulet'},
    'jambon blanc': {'jambon'},
    'Jambon cru': {'jambon_cru'},
    'cordon bleu': <String>{},
    'mozzarella': {'mozzarella'},
    'pâte brisée': {'pate_brisee'},
    'saucisse de Morteau': {'saucisse_fumee'},
    'Pommes de terre': {'pomme_de_terre'},
    'Pommes golden': {'pomme'},
    'Oeufs': {'oeufs'},
    'œufs bio': {'oeufs'},
    'Steak haché': {'boeuf_hache'},
    'Lait de coco': {'lait_coco'},
    'Crème fraîche épaisse': {'creme'},
    'Chou-fleur': {'chou_fleur'},
    'Tomates cerises': {'tomate'},
    'Lardons fumés': {'lardons'},
    'Saumon fumé': {'saumon_fume'},
  };

  for (final MapEntry(key: product, value: expected) in cases.entries) {
    test('« $product » → $expected', () => expect(matcher.keysFor(product), expected));
  }
}
