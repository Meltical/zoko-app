import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../recipes/data/recipe_providers.dart';
import '../domain/product.dart';
import 'consume_actions.dart';
import 'expiry_badge.dart';

class ProductTile extends ConsumerWidget {
  const ProductTile({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expiry = product.expiry;
    final recipeCount = ref.watch(productRecipeCountProvider(product.name));
    final urgentColor = expiry.isUrgent ? expiry.color(theme.brightness) : theme.colorScheme.onSurfaceVariant;

    return Dismissible(
      key: ValueKey(product.id),
      background: const _SwipeBackground(outcome: ConsumptionOutcome.eaten),
      secondaryBackground: const _SwipeBackground(outcome: ConsumptionOutcome.wasted),
      onDismissed: (direction) => consumeWithUndo(
        context,
        ref,
        product,
        direction == DismissDirection.startToEnd ? ConsumptionOutcome.eaten : ConsumptionOutcome.wasted,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 8),
        onTap: () => context.push(Routes.product(product.id)),
        leading: ExpiryBadge(expiry: expiry),
        title: Text.rich(
          TextSpan(
            text: product.name,
            children: [
              if (product.quantity > 1)
                TextSpan(
                  text: '  ×${product.quantity}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            if (product.location != StorageLocation.fridge) ...[
              Icon(product.location.icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(expiry.label, style: TextStyle(color: urgentColor)),
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: recipeCount == 0 ? 'Chercher une recette' : '$recipeCount recettes avec ${product.name}',
          color: recipeCount == 0 ? theme.colorScheme.outline : theme.colorScheme.primary,
          onPressed: () => context.push(Routes.productRecipes(product.id)),
          icon: Badge.count(
            count: recipeCount,
            isLabelVisible: recipeCount > 0,
            backgroundColor: theme.colorScheme.primary,
            child: const Icon(Icons.restaurant_menu),
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.outcome});

  final ConsumptionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final eaten = outcome == ConsumptionOutcome.eaten;
    return ColoredBox(
      color: eaten ? const Color(0xFF2E7D32) : Theme.of(context).colorScheme.error,
      child: Align(
        alignment: eaten ? Alignment.centerLeft : Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Icon(eaten ? Icons.check : Icons.delete_outline, color: Colors.white),
              Text(
                eaten ? 'Mangé' : 'Jeté',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
