import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase.dart';
import '../domain/recipe.dart';

final recipesRepositoryProvider = Provider<RecipesRepository>((ref) => RecipesRepository(ref.watch(supabaseProvider)));

class RecipesRepository {
  RecipesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Recipe>> fetchRecipes() async {
    final rows = await _client.from('recipes').select().order('title');
    return rows.map(Recipe.fromJson).toList();
  }

  Future<List<Ingredient>> fetchIngredients() async {
    final rows = await _client.from('ingredients').select();
    return rows.map(Ingredient.fromJson).toList();
  }
}
