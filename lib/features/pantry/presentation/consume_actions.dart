import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pantry_providers.dart';
import '../domain/product.dart';

Future<void> consumeWithUndo(BuildContext context, WidgetRef ref, Product product, ConsumptionOutcome outcome) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(productsProvider.notifier);
  try {
    final historyId = await notifier.consume(product, outcome);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (outcome) {
            ConsumptionOutcome.eaten => '« ${product.name} » mangé',
            ConsumptionOutcome.wasted => '« ${product.name} » jeté',
          }),
          action: SnackBarAction(label: 'Annuler', onPressed: () => _restore(messenger, notifier, product, historyId)),
        ),
      );
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Impossible de retirer « ${product.name} » : $error')));
  }
}

Future<void> removeWithUndo(BuildContext context, WidgetRef ref, Product product) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(productsProvider.notifier);
  try {
    await notifier.remove(product);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('« ${product.name} » supprimé'),
          action: SnackBarAction(label: 'Annuler', onPressed: () => _restore(messenger, notifier, product, null)),
        ),
      );
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Suppression impossible : $error')));
  }
}

Future<void> _restore(
  ScaffoldMessengerState messenger,
  ProductsNotifier notifier,
  Product product,
  int? historyId,
) async {
  try {
    await notifier.restore(product, historyId: historyId);
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Annulation impossible : $error')));
  }
}
