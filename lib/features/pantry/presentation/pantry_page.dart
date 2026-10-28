import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../shared/async_views.dart';
import '../../recipes/data/recipe_providers.dart';
import '../data/pantry_providers.dart';
import '../domain/product.dart';
import 'add_product_sheet.dart';
import 'product_tile.dart';

class PantryPage extends ConsumerStatefulWidget {
  const PantryPage({super.key});

  @override
  ConsumerState<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends ConsumerState<PantryPage> {
  StorageLocation? _filter;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddProductSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: switch (products) {
        AsyncValue(:final value?) => _buildList(value),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(productsProvider)),
        _ => const LoadingView(),
      },
    );
  }

  Widget _buildList(List<Product> all) {
    final theme = Theme.of(context);
    final locations = {for (final product in all) product.location};
    final filter = locations.length > 1 ? _filter : null;
    final products = [
      for (final product in all)
        if (filter == null || product.location == filter) product,
    ];
    final sections = [
      (
        'À consommer vite',
        theme.colorScheme.error,
        [
          for (final p in products)
            if (p.expiry.daysLeft <= 2) p,
        ],
      ),
      (
        'Cette semaine',
        theme.colorScheme.onSurfaceVariant,
        [
          for (final p in products)
            if (p.expiry.daysLeft > 2 && p.expiry.daysLeft <= 7) p,
        ],
      ),
      (
        'Plus tard',
        theme.colorScheme.onSurfaceVariant,
        [
          for (final p in products)
            if (p.expiry.daysLeft > 7) p,
        ],
      ),
    ];
    final cookable = ref.watch(cookableRecipesProvider).length;
    final stats = ref.watch(monthStatsProvider).value;

    return RefreshIndicator(
      onRefresh: ref.read(productsProvider.notifier).refresh,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('Mon frigo'),
            actions: [
              IconButton(
                tooltip: 'Réglages et foyer',
                onPressed: () => context.push(Routes.settings),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          if (cookable > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Card(
                  color: theme.colorScheme.primaryContainer,
                  child: ListTile(
                    onTap: () => context.go(Routes.recipes),
                    leading: Icon(Icons.restaurant_menu, color: theme.colorScheme.onPrimaryContainer),
                    title: Text(
                      cookable == 1 ? '1 recette réalisable' : '$cookable recettes réalisables',
                      style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'avec ce que vous avez, les plus urgentes d’abord',
                      style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                    ),
                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              ),
            ),
          if (locations.length > 1)
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tout'),
                      selected: filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    for (final location in StorageLocation.values)
                      if (locations.contains(location))
                        ChoiceChip(
                          avatar: Icon(location.icon, size: 18),
                          label: Text(location.label),
                          selected: filter == location,
                          onSelected: (_) => setState(() => _filter = location),
                        ),
                  ],
                ),
              ),
            ),
          if (all.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(
                icon: Icons.kitchen_outlined,
                title: 'Le frigo est vide',
                message: 'Ajoutez vos courses : un nom, une date, et c’est tout.',
                action: FilledButton.icon(
                  onPressed: () => showAddProductSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un produit'),
                ),
              ),
            ),
          for (final (title, color, items) in sections)
            if (items.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: color)),
                ),
              ),
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => ProductTile(key: ValueKey(items[index].id), product: items[index]),
              ),
            ],
          if (stats != null && stats.total > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text(
                  'Ce mois-ci : ${stats.eaten} mangé${stats.eaten > 1 ? 's' : ''}, '
                  '${stats.wasted} jeté${stats.wasted > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
        ],
      ),
    );
  }
}
