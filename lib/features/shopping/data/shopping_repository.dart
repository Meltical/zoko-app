import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepository(ref.watch(supabaseProvider)),
);

class ShoppingItem {
  const ShoppingItem({required this.id, required this.name, required this.done, this.note});

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    note: json['note'] as String?,
    done: json['done'] as bool? ?? false,
  );

  final int id;
  final String name;
  final String? note;
  final bool done;

  ShoppingItem copyWith({bool? done}) => ShoppingItem(id: id, name: name, note: note, done: done ?? this.done);
}

class ShoppingRepository {
  ShoppingRepository(this._client);

  final SupabaseClient _client;

  SupabaseQueryBuilder get _items => _client.from('shopping_items');

  Future<List<ShoppingItem>> fetchAll(String householdId) async {
    final rows = await _items.select().eq('household_id', householdId).order('created_at');
    return rows.map(ShoppingItem.fromJson).toList();
  }

  RealtimeChannel subscribe(String householdId, void Function() onChange) => _client
      .channel('shopping:$householdId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shopping_items',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'household_id', value: householdId),
        callback: (_) => onChange(),
      )
      .subscribe();

  Future<List<ShoppingItem>> addAll(String householdId, List<({String name, String? note})> items) async {
    if (items.isEmpty) return const [];
    final rows = await _items.insert([
      for (final item in items) {'household_id': householdId, 'name': item.name.trim(), 'note': item.note},
    ]).select();
    return rows.map(ShoppingItem.fromJson).toList();
  }

  Future<void> setDone(int id, bool done) => _items.update({'done': done}).eq('id', id);

  Future<void> deleteAll(Iterable<int> ids) => _items.delete().inFilter('id', ids.toList());
}
