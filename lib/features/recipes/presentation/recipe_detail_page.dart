import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/async_views.dart';
import '../../pantry/data/pantry_providers.dart';
import '../../pantry/domain/product.dart';
import '../../shopping/data/shopping_providers.dart';
import '../data/recipe_providers.dart';
import '../domain/recipe_match.dart';
import 'recipe_widgets.dart';

class RecipeDetailPage extends ConsumerWidget {
  const RecipeDetailPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(recipeCatalogProvider);
    final match = ref.watch(recipeMatchProvider(slug));
    if (match == null) {
      return Scaffold(
        appBar: AppBar(),
        body: switch (catalog) {
          AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(recipeCatalogProvider)),
          AsyncValue(hasValue: true) => const EmptyView(icon: Icons.search_off, title: 'Recette introuvable'),
          _ => const LoadingView(),
        },
      );
    }

    final theme = Theme.of(context);
    final recipe = match.recipe;
    final staples = [
      for (final item in match.ingredients)
        if (item.status == IngredientStatus.staple) item.ingredient.label,
    ];
    final listed = [
      for (final item in match.ingredients)
        if (item.status != IngredientStatus.staple) item,
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            flexibleSpace: FlexibleSpaceBar(background: RecipeImage(recipe: recipe)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            sliver: SliverList.list(
              children: [
                Text(recipe.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (recipe.prepMinutes != null || recipe.cookMinutes != null)
                      Chip(
                        avatar: const Icon(Icons.schedule, size: 18),
                        label: Text(
                          [
                            if (recipe.prepMinutes != null) '${recipe.prepMinutes} min de prépa',
                            if ((recipe.cookMinutes ?? 0) > 0) '${recipe.cookMinutes} min de cuisson',
                          ].join(' + '),
                        ),
                      ),
                    if (recipe.servings != null) Chip(label: Text('${recipe.servings} pers.')),
                    if (recipe.difficulty != null) Chip(label: Text(_capitalize(recipe.difficulty!))),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Ingrédients', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final item in listed) _IngredientRow(item: item),
                if (staples.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Au placard : ',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextSpan(text: staples.join(', ')),
                        ],
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (match.missing.isNotEmpty) ...[const SizedBox(height: 12), _AddMissingButton(match: match)],
                const SizedBox(height: 24),
                Text('Préparation', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final (index, step) in recipe.steps.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ),
                        Expanded(child: Text(step, style: theme.textTheme.bodyLarge)),
                      ],
                    ),
                  ),
                if (recipe.imageCredit != null) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: recipe.imageSource == null
                        ? null
                        : () => launchUrl(Uri.parse(recipe.imageSource!), mode: LaunchMode.externalApplication),
                    child: Text(
                      recipe.imageCredit!,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: match.usedProducts.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _showCookedSheet(context, match),
                  icon: const Icon(Icons.check),
                  label: const Text('J’ai cuisiné ça'),
                ),
              ),
            ),
    );
  }

  static String _capitalize(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.item});

  final IngredientMatch item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = item.status == IngredientStatus.available;
    final optional = item.ingredient.optional;
    final products = item.products;
    final detail = available
        ? products.map((product) => '${product.name} · ${product.expiry.label.toLowerCase()}').join(', ')
        : optional
        ? 'Facultatif'
        : 'À acheter';
    final urgent = products.any((product) => product.expiry.isUrgent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Icon(
            available ? Icons.check_circle : Icons.radio_button_unchecked,
            color: available ? const Color(0xFF2E7D32) : theme.colorScheme.outline,
            semanticLabel: available ? 'Disponible' : 'Absent',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(item.ingredient.label, style: theme.textTheme.bodyLarge),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: urgent
                        ? theme.colorScheme.error
                        : available
                        ? const Color(0xFF3F6B1C)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMissingButton extends ConsumerWidget {
  const _AddMissingButton({required this.match});

  final RecipeMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    onPressed: () async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final added = await ref.read(shoppingProvider.notifier).addMissing([
          for (final item in match.missing) (name: item.name, note: match.recipe.title),
        ]);
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (added) {
              0 => 'Déjà dans la liste de courses',
              1 => '1 article ajouté aux courses',
              _ => '$added articles ajoutés aux courses',
            }),
          ),
        );
      } catch (error) {
        messenger.showSnackBar(SnackBar(content: Text('Ajout impossible : $error')));
      }
    },
    icon: const Icon(Icons.add_shopping_cart),
    label: Text(
      'Ajouter ${match.missing.length == 1 ? 'le manquant' : 'les ${match.missing.length} manquants'} aux courses',
    ),
  );
}

Future<void> _showCookedSheet(BuildContext context, RecipeMatch match) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _CookedSheet(match: match),
);

class _CookedSheet extends ConsumerStatefulWidget {
  const _CookedSheet({required this.match});

  final RecipeMatch match;

  @override
  ConsumerState<_CookedSheet> createState() => _CookedSheetState();
}

class _CookedSheetState extends ConsumerState<_CookedSheet> {
  late final Set<int> _selected = {
    for (final product in widget.match.usedProducts)
      if (product.location != StorageLocation.pantry) product.id,
  };
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(productsProvider.notifier);
    final chosen = [
      for (final product in widget.match.usedProducts)
        if (_selected.contains(product.id)) product,
    ];
    var failures = 0;
    for (final product in chosen) {
      try {
        await notifier.consume(product, ConsumptionOutcome.eaten);
      } catch (_) {
        failures++;
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failures == 0
              ? '${chosen.length} produit${chosen.length > 1 ? 's' : ''} retiré${chosen.length > 1 ? 's' : ''} du frigo'
              : '$failures produit(s) n’ont pas pu être retirés',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Retirer du frigo ce qui a été utilisé', style: theme.textTheme.titleMedium),
          ),
          for (final product in widget.match.usedProducts)
            CheckboxListTile(
              value: _selected.contains(product.id),
              onChanged: (checked) => setState(() {
                if (checked ?? false) {
                  _selected.add(product.id);
                } else {
                  _selected.remove(product.id);
                }
              }),
              title: Text(product.name),
              subtitle: Text(product.expiry.label),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _busy || _selected.isEmpty ? null : _confirm,
              child: Text(
                _selected.isEmpty
                    ? 'Rien à retirer'
                    : 'Retirer ${_selected.length} produit${_selected.length > 1 ? 's' : ''}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
