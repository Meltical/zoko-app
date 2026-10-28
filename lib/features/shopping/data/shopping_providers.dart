import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text.dart';
import '../../household/data/household_providers.dart';
import 'shopping_repository.dart';

final shoppingProvider = AsyncNotifierProvider<ShoppingNotifier, List<ShoppingItem>>(ShoppingNotifier.new);

final pendingShoppingCountProvider = Provider<int>(
  (ref) => (ref.watch(shoppingProvider).value ?? const []).where((item) => !item.done).length,
);

class ShoppingNotifier extends AsyncNotifier<List<ShoppingItem>> {
  Timer? _debounce;

  ShoppingRepository get _repository => ref.read(shoppingRepositoryProvider);

  String get _householdId => ref.read(householdIdProvider)!;

  @override
  Future<List<ShoppingItem>> build() async {
    final repository = ref.watch(shoppingRepositoryProvider);
    final householdId = ref.watch(householdIdProvider);
    if (householdId == null) return const [];
    final channel = repository.subscribe(householdId, _scheduleRefresh);
    final lifecycle = AppLifecycleListener(onResume: _scheduleRefresh);
    ref.onDispose(() {
      _debounce?.cancel();
      lifecycle.dispose();
      channel.unsubscribe();
    });
    return repository.fetchAll(householdId);
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final householdId = ref.read(householdIdProvider);
      if (householdId == null) return;
      try {
        state = AsyncData(await _repository.fetchAll(householdId));
      } catch (_) {}
    });
  }

  Future<int> addMissing(List<({String name, String? note})> items) async {
    final existing = {
      for (final item in state.value ?? const <ShoppingItem>[])
        if (!item.done) normalizeText(item.name),
    };
    final fresh = <({String name, String? note})>[];
    for (final item in items) {
      final key = normalizeText(item.name);
      if (key.isEmpty || !existing.add(key)) continue;
      fresh.add(item);
    }
    final added = await _repository.addAll(_householdId, fresh);
    state = AsyncData([...?state.value, ...added]);
    return added.length;
  }

  Future<void> toggle(ShoppingItem item) async {
    _replace(item.copyWith(done: !item.done));
    try {
      await _repository.setDone(item.id, !item.done);
    } catch (_) {
      _replace(item);
      rethrow;
    }
  }

  Future<void> removeAll(Iterable<int> ids) async {
    final removed = ids.toSet();
    final previous = state.value ?? const <ShoppingItem>[];
    state = AsyncData([
      for (final item in previous)
        if (!removed.contains(item.id)) item,
    ]);
    try {
      await _repository.deleteAll(removed);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  void _replace(ShoppingItem updated) {
    state = AsyncData([
      for (final item in state.value ?? const <ShoppingItem>[]) item.id == updated.id ? updated : item,
    ]);
  }
}
