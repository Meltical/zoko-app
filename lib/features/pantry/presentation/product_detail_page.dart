import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router.dart';
import '../../../shared/async_views.dart';
import '../../recipes/data/recipe_providers.dart';
import '../data/pantry_providers.dart';
import '../domain/product.dart';
import 'consume_actions.dart';
import 'expiry_badge.dart';
import 'product_form_fields.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final int productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  late final ProductsNotifier _notifier = ref.read(productsProvider.notifier);
  final _name = TextEditingController();
  Timer? _nameDebounce;
  Product? _pendingName;

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(productProvider(widget.productId))?.name ?? '';
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    if (_pendingName != null) unawaited(_notifier.save(_pendingName!));
    _name.dispose();
    super.dispose();
  }

  void _onNameChanged(Product product, String value) {
    if (value.trim().isEmpty) return;
    _pendingName = product.copyWith(name: value.trim());
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 700), () {
      final pending = _pendingName;
      _pendingName = null;
      if (pending != null) _save(pending);
    });
  }

  Future<void> _save(Product product) async {
    try {
      await _notifier.save(product);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enregistrement impossible : $error')));
      }
    }
  }

  Product _withPendingName(Product product) =>
      _pendingName == null ? product : product.copyWith(name: _pendingName!.name);

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productProvider(widget.productId));
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(icon: Icons.check_circle_outline, title: 'Ce produit n’est plus dans le frigo'),
      );
    }

    final theme = Theme.of(context);
    final expiry = product.expiry;
    final color = expiry.color(theme.brightness);
    final recipeCount = ref.watch(productRecipeCountProvider(product.name));

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            tooltip: 'Supprimer (erreur de saisie)',
            onPressed: () {
              removeWithUndo(context, ref, product);
              context.pop();
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: color.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                spacing: 16,
                children: [
                  ExpiryBadge(expiry: expiry, size: 56),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(expiry.label, style: theme.textTheme.titleLarge?.copyWith(color: color)),
                        Text(
                          '${DateFormat('EEEE d MMMM', 'fr').format(product.exp)} · '
                          'ajouté le ${DateFormat('d MMM', 'fr').format(product.createdAt)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => context.push(Routes.productRecipes(product.id)),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), alignment: Alignment.centerLeft),
            icon: const Icon(Icons.restaurant_menu),
            label: Text(switch (recipeCount) {
              0 => 'Chercher une recette',
              1 => '1 recette avec ce produit',
              _ => '$recipeCount recettes avec ce produit',
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nom'),
            onChanged: (value) => _onNameChanged(product, value),
          ),
          const SizedBox(height: 20),
          ExpiryPicker(
            label: 'Date de péremption',
            value: product.exp,
            location: product.location,
            onChanged: (exp) => _save(_withPendingName(product).copyWith(exp: exp)),
          ),
          const SizedBox(height: 20),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: LocationSelector(
                  value: product.location,
                  onChanged: (location) => _save(_withPendingName(product).copyWith(location: location)),
                ),
              ),
              QuantityStepper(
                value: product.quantity,
                onChanged: (quantity) => _save(_withPendingName(product).copyWith(quantity: quantity)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Chaque modification est enregistrée tout de suite.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => _consume(product, ConsumptionOutcome.eaten),
                  icon: const Icon(Icons.check),
                  label: const Text('Mangé'),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => _consume(product, ConsumptionOutcome.wasted),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Jeté'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _consume(Product product, ConsumptionOutcome outcome) {
    _nameDebounce?.cancel();
    _pendingName = null;
    consumeWithUndo(context, ref, product, outcome);
    context.pop();
  }
}
