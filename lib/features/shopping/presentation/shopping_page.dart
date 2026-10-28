import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text.dart';
import '../../../shared/async_views.dart';
import '../../pantry/presentation/add_product_sheet.dart';
import '../data/shopping_providers.dart';
import '../data/shopping_repository.dart';

class ShoppingPage extends ConsumerStatefulWidget {
  const ShoppingPage({super.key});

  @override
  ConsumerState<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends ConsumerState<ShoppingPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _input.text.trim();
    if (name.isEmpty) return;
    _input.clear();
    _focus.requestFocus();
    try {
      await ref.read(shoppingProvider.notifier).addMissing([(name: name, note: null)]);
    } catch (error) {
      if (mounted) _snack('Ajout impossible : $error');
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _putAway(List<ShoppingItem> done) async {
    final notifier = ref.read(shoppingProvider.notifier);
    final remaining = [...done];
    await showAddProductSheet(
      context,
      queue: [for (final item in done) item.name],
      onAdded: (name) {
        final key = normalizeText(name);
        final index = remaining.indexWhere((item) => normalizeText(item.name) == key);
        if (index < 0) return;
        final item = remaining.removeAt(index);
        notifier.removeAll([item.id]).ignore();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(shoppingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      body: switch (items) {
        AsyncValue(:final value?) => _buildList(value),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(shoppingProvider)),
        _ => const LoadingView(),
      },
    );
  }

  Widget _buildList(List<ShoppingItem> items) {
    final theme = Theme.of(context);
    final pending = [
      for (final item in items)
        if (!item.done) item,
    ];
    final done = [
      for (final item in items)
        if (item.done) item,
    ];
    final notifier = ref.read(shoppingProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _input,
            focusNode: _focus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onEditingComplete: () {},
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: 'Ajouter un article',
              prefixIcon: const Icon(Icons.add),
              suffixIcon: IconButton(tooltip: 'Ajouter', onPressed: _add, icon: const Icon(Icons.keyboard_return)),
            ),
          ),
        ),
        if (items.isEmpty)
          const EmptyView(
            icon: Icons.shopping_basket_outlined,
            title: 'La liste est vide',
            message: 'Ajoutez un article ici, ou depuis une recette avec « Ajouter les manquants aux courses ».',
          ),
        for (final item in pending)
          Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            background: ColoredBox(
              color: theme.colorScheme.error,
              child: const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 24),
                  child: Icon(Icons.delete_outline, color: Colors.white),
                ),
              ),
            ),
            onDismissed: (_) => notifier.removeAll([item.id]).catchError((Object error) => _snack('$error')),
            child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              value: false,
              onChanged: (_) => notifier.toggle(item).catchError((Object error) => _snack('$error')),
              title: Text(item.name),
              subtitle: item.note == null ? null : Text('pour ${item.note}'),
            ),
          ),
        if (done.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
            child: Row(
              children: [
                Expanded(child: Text('Dans le panier · ${done.length}', style: theme.textTheme.titleSmall)),
                TextButton(
                  onPressed: () =>
                      notifier.removeAll(done.map((item) => item.id)).catchError((Object error) => _snack('$error')),
                  child: const Text('Retirer'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: FilledButton.tonalIcon(
              onPressed: () => _putAway(done),
              icon: const Icon(Icons.kitchen_outlined),
              label: Text('Ranger dans le frigo (${done.length})'),
            ),
          ),
          for (final item in done)
            CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              value: true,
              onChanged: (_) => notifier.toggle(item).catchError((Object error) => _snack('$error')),
              title: Text(
                item.name,
                style: TextStyle(decoration: TextDecoration.lineThrough, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ],
    );
  }
}
