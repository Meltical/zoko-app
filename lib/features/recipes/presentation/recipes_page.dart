import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/async_views.dart';
import '../data/recipe_providers.dart';
import '../domain/recipe_match.dart';
import 'recipe_widgets.dart';

enum _RecipeFilter { cookable, almost, all }

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  _RecipeFilter? _filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = ref.watch(recipeCatalogProvider);
    final cookable = ref.watch(cookableRecipesProvider);
    final almost = ref.watch(partialRecipesProvider).where((match) => match.missing.length <= 2).toList();
    final all = [...ref.watch(recipeMatchesProvider)]..sort((a, b) => a.recipe.title.compareTo(b.recipe.title));
    final filter = _filter ?? (cookable.isEmpty ? _RecipeFilter.almost : _RecipeFilter.cookable);
    final List<RecipeMatch> shown = switch (filter) {
      _RecipeFilter.cookable => cookable,
      _RecipeFilter.almost => almost,
      _RecipeFilter.all => all,
    };

    return Scaffold(
      body: switch (catalog) {
        AsyncValue(:final error?) when !catalog.hasValue => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(recipeCatalogProvider),
        ),
        AsyncValue(hasValue: false) => const LoadingView(),
        _ => CustomScrollView(
          slivers: [
            const SliverAppBar(floating: true, title: Text('Que cuisiner ?')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Text(
                      'Ce qui périme en premier passe en premier.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    SegmentedButton<_RecipeFilter>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: _RecipeFilter.cookable, label: Text('Réalisables · ${cookable.length}')),
                        ButtonSegment(value: _RecipeFilter.almost, label: Text('Presque · ${almost.length}')),
                        const ButtonSegment(value: _RecipeFilter.all, label: Text('Toutes')),
                      ],
                      selected: {filter},
                      onSelectionChanged: (selection) => setState(() => _filter = selection.single),
                    ),
                  ],
                ),
              ),
            ),
            if (shown.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  icon: Icons.restaurant_menu,
                  title: filter == _RecipeFilter.cookable
                      ? 'Aucune recette complète avec le frigo actuel'
                      : 'Aucune recette à proposer',
                  message: filter == _RecipeFilter.cookable
                      ? 'Regardez l’onglet « Presque » : il manque souvent un seul ingrédient.'
                      : 'Ajoutez quelques produits au frigo pour voir des idées.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => filter == _RecipeFilter.all
                      ? RecipeListCard(match: shown[index])
                      : RecipeCard(match: shown[index]),
                ),
              ),
          ],
        ),
      },
    );
  }
}
