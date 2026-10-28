import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates.dart';
import '../../household/data/household_providers.dart';
import '../domain/product.dart';
import '../domain/suggestion.dart';
import 'products_repository.dart';

final productsProvider = AsyncNotifierProvider<ProductsNotifier, List<Product>>(ProductsNotifier.new);

final productProvider = Provider.family<Product?, int>((ref, id) {
  final products = ref.watch(productsProvider).value ?? const [];
  for (final product in products) {
    if (product.id == id) return product;
  }
  return null;
});

final suggestionsProvider = FutureProvider<List<ProductSuggestion>>((ref) async {
  final householdId = ref.watch(householdIdProvider);
  if (householdId == null) return const [];
  return ref.watch(productsRepositoryProvider).fetchSuggestions(householdId);
});

final monthStatsProvider = FutureProvider<WasteStats>((ref) async {
  ref.watch(productsProvider.select((state) => state.value?.length));
  final householdId = ref.watch(householdIdProvider);
  if (householdId == null) return const WasteStats(eaten: 0, wasted: 0);
  final now = today();
  return ref.watch(productsRepositoryProvider).fetchStats(householdId, since: DateTime(now.year, now.month));
});

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  Timer? _debounce;
  final _pendingRemovals = <int>{};

  ProductsRepository get _repository => ref.read(productsRepositoryProvider);

  String get _householdId => ref.read(householdIdProvider)!;

  @override
  Future<List<Product>> build() async {
    final repository = ref.watch(productsRepositoryProvider);
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
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  Future<void> refresh() async {
    try {
      final householdId = ref.read(householdIdProvider);
      if (householdId == null) return;
      final products = await _repository.fetchAll(householdId);
      state = AsyncData([
        for (final product in products)
          if (!_pendingRemovals.contains(product.id)) product,
      ]);
    } catch (error, stackTrace) {
      if (!state.hasValue) state = AsyncError(error, stackTrace);
    }
  }

  Future<Product> add(ProductDraft draft) async {
    final product = await _repository.add(_householdId, draft);
    _upsertLocal(product);
    ref.invalidate(suggestionsProvider);
    return product;
  }

  Future<void> save(Product product) async {
    final previous = _find(product.id);
    _upsertLocal(product);
    try {
      await _repository.update(product);
    } catch (_) {
      if (previous != null) _upsertLocal(previous);
      rethrow;
    }
  }

  Future<int> consume(Product product, ConsumptionOutcome outcome) =>
      _removeOptimistically(product, () => _repository.archive(product, outcome));

  Future<void> remove(Product product) => _removeOptimistically(product, () => _repository.delete(product.id));

  Future<T> _removeOptimistically<T>(Product product, Future<T> Function() operation) async {
    _pendingRemovals.add(product.id);
    _removeLocal(product.id);
    try {
      return await operation();
    } catch (_) {
      _upsertLocal(product);
      rethrow;
    } finally {
      _pendingRemovals.remove(product.id);
    }
  }

  Future<void> restore(Product product, {int? historyId}) async {
    final restored = await _repository.restore(_householdId, product, historyId: historyId);
    _upsertLocal(restored);
  }

  Product? _find(int id) {
    for (final product in state.value ?? const <Product>[]) {
      if (product.id == id) return product;
    }
    return null;
  }

  void _upsertLocal(Product product) {
    final products = [...?state.value]..removeWhere((p) => p.id == product.id);
    state = AsyncData([...products, product]..sort(compareByExpiry));
  }

  void _removeLocal(int id) {
    state = AsyncData([...?state.value]..removeWhere((p) => p.id == id));
  }
}
