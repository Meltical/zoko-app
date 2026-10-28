import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/async_views.dart';
import '../../pantry/data/pantry_providers.dart';
import '../data/recipe_providers.dart';
import 'recipe_widgets.dart';

class ProductRecipesPage extends ConsumerWidget {
  const ProductRecipesPage({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final product = ref.watch(productProvider(productId));
    final catalog = ref.watch(recipeCatalogProvider);
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(icon: Icons.check_circle_outline, title: 'Ce produit n’est plus dans le frigo'),
      );
    }
    final matches = ref.watch(productRecipesProvider(product.name));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recettes avec', style: theme.textTheme.labelMedium),
            Text(product.name),
          ],
        ),
      ),
      body: switch (catalog) {
        AsyncValue(:final error?) when !catalog.hasValue => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(recipeCatalogProvider),
        ),
        AsyncValue(hasValue: false) => const LoadingView(),
        _ => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Aucune recette du catalogue n’utilise « ${product.name} ».',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            for (final match in matches) ...[
              RecipeListCard(match: match, highlight: product),
              const SizedBox(height: 12),
            ],
            _MarmitonCard(query: product.name),
          ],
        ),
      },
    );
  }
}

class _MarmitonCard extends StatelessWidget {
  const _MarmitonCard({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Text('Envie d’autre chose ?', style: theme.textTheme.titleSmall),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.https('www.marmiton.org', '/recettes/recherche.aspx', {'aqt': query}),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Plus d’idées sur Marmiton'),
            ),
          ],
        ),
      ),
    );
  }
}
