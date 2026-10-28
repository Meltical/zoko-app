import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../pantry/domain/product.dart';
import '../domain/recipe.dart';
import '../domain/recipe_match.dart';

const _imageHeaders = {'User-Agent': 'Zoko/2.0 (https://github.com/Meltical/zoko-app)'};

class RecipeImage extends StatelessWidget {
  const RecipeImage({super.key, required this.recipe, this.width, this.height, this.borderRadius});

  final Recipe recipe;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(width: width, height: height);
    final image = recipe.imageUrl == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: recipe.imageUrl!,
            httpHeaders: _imageHeaders,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
    return ClipRRect(borderRadius: borderRadius ?? BorderRadius.zero, child: image);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: scheme.secondaryContainer,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, color: scheme.onSecondaryContainer.withValues(alpha: 0.5)),
    );
  }
}

String recipeDuration(Recipe recipe) {
  final minutes = recipe.totalMinutes;
  if (minutes == null) return '';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h ${rest.toString().padLeft(2, '0')}';
}

class MatchStatusChip extends StatelessWidget {
  const MatchStatusChip({super.key, required this.match});

  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final complete = match.isComplete;
    final background = complete ? const Color(0xFFE5F2E6) : const Color(0xFFFFF0D6);
    final foreground = complete ? const Color(0xFF1B5E20) : const Color(0xFF7A4300);
    final missing = match.missing.map((item) => item.ingredient.label).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        complete ? 'Tout est là' : 'Manque : ${_missingNames(match)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        semanticsLabel: complete ? 'Tous les ingrédients sont là' : 'Il manque ${missing.join(', ')}',
        style: TextStyle(color: foreground, fontSize: 12.5, fontWeight: FontWeight.w500),
      ),
    );
  }
}

String _missingNames(RecipeMatch match) => match.missing.map((item) => item.name).join(', ');

String usedProductsLabel(List<Product> products) => [
  for (final product in products)
    product.expiry.isUrgent ? '${product.name} (${product.expiry.label.toLowerCase()})' : product.name,
].join(', ');

class RecipeListCard extends StatelessWidget {
  const RecipeListCard({super.key, required this.match, this.highlight});

  final RecipeMatch match;
  final Product? highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = match.recipe;
    final others = [
      for (final product in match.usedProducts)
        if (product.id != highlight?.id) product,
    ];
    final meta = [
      recipeDuration(recipe),
      if (recipe.servings != null) '${recipe.servings} pers.',
      ?recipe.difficulty,
    ].where((part) => part.isNotEmpty).join(' · ');

    return Card(
      child: InkWell(
        onTap: () => context.push(Routes.recipe(recipe.slug)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              RecipeImage(recipe: recipe, width: 92, height: 92, borderRadius: BorderRadius.circular(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(recipe.title, style: theme.textTheme.titleMedium),
                    if (meta.isNotEmpty)
                      Text(meta, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    MatchStatusChip(match: match),
                    if (others.isNotEmpty)
                      Text(
                        'Utilise aussi : ${usedProductsLabel(others)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.match});

  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = match.recipe;
    final urgent = match.urgentProducts.isNotEmpty;
    final usage = usedProductsLabel(match.usedProducts);

    return Card(
      child: InkWell(
        onTap: () => context.push(Routes.recipe(recipe.slug)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecipeImage(recipe: recipe, height: 132),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(recipe.title, style: theme.textTheme.titleMedium)),
                      Text(
                        recipeDuration(recipe),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (usage.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Icon(
                          urgent ? Icons.local_fire_department_outlined : Icons.kitchen_outlined,
                          size: 16,
                          color: urgent ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Text(
                            usage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: urgent ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!match.isComplete) MatchStatusChip(match: match),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
