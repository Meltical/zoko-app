import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/dates.dart';
import '../../../core/supabase.dart';
import '../domain/product.dart';
import '../domain/suggestion.dart';

final productsRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ProductsRepository(ref.watch(supabaseProvider)),
);

class ProductsRepository {
  ProductsRepository(this._client);

  final SupabaseClient _client;

  SupabaseQueryBuilder get _products => _client.from('products');

  SupabaseQueryBuilder get _history => _client.from('product_history');

  Future<List<Product>> fetchAll(String householdId) async {
    final rows = await _products.select().eq('household_id', householdId).order('exp');
    return rows.map(Product.fromJson).toList()..sort(compareByExpiry);
  }

  RealtimeChannel subscribe(String householdId, void Function() onChange) => _client
      .channel('products:$householdId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'products',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'household_id', value: householdId),
        callback: (_) => onChange(),
      )
      .subscribe();

  Future<Product> add(String householdId, ProductDraft draft) async =>
      Product.fromJson(await _products.insert({...draft.toJson(), 'household_id': householdId}).select().single());

  Future<void> update(Product product) => _products
      .update({
        'name': product.name.trim(),
        'exp': formatDbDate(product.exp),
        'quantity': product.quantity,
        'location': product.location.value,
      })
      .eq('id', product.id);

  Future<void> delete(int id) => _products.delete().eq('id', id);

  Future<int> archive(Product product, ConsumptionOutcome outcome) async {
    final row = await _history
        .insert({
          'name': product.name,
          'exp': formatDbDate(product.exp),
          'quantity': product.quantity,
          'location': product.location.value,
          'added_at': product.createdAt.toUtc().toIso8601String(),
          'outcome': outcome.value,
        })
        .select('id')
        .single();
    await delete(product.id);
    return (row['id'] as num).toInt();
  }

  Future<Product> restore(String householdId, Product product, {int? historyId}) async {
    final restored = await add(householdId, product.toDraft());
    if (historyId != null) await _history.delete().eq('id', historyId);
    return restored;
  }

  Future<List<ProductSuggestion>> fetchSuggestions(String householdId) async {
    final rows = await _client
        .from('product_suggestions')
        .select()
        .eq('household_id', householdId)
        .order('uses', ascending: false);
    return rows.map(ProductSuggestion.fromJson).toList();
  }

  Future<WasteStats> fetchStats(String householdId, {required DateTime since}) async {
    final rows = await _history
        .select('outcome')
        .eq('household_id', householdId)
        .gte('logged_at', since.toUtc().toIso8601String());
    final wasted = rows.where((row) => row['outcome'] == ConsumptionOutcome.wasted.value).length;
    return WasteStats(eaten: rows.length - wasted, wasted: wasted);
  }
}

class WasteStats {
  const WasteStats({required this.eaten, required this.wasted});

  final int eaten;
  final int wasted;

  int get total => eaten + wasted;
}
