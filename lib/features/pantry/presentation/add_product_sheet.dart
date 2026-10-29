import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates.dart';
import '../../../core/preferences.dart';
import '../data/pantry_providers.dart';
import '../domain/product.dart';
import '../domain/quick_entry.dart';
import '../domain/suggestion.dart';
import 'product_form_fields.dart';

Future<void> showAddProductSheet(
  BuildContext context, {
  StorageLocation? location,
  List<String> queue = const [],
  ValueChanged<String>? onAdded,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: AddProductSheet(location: location, queue: queue, onAdded: onAdded),
  ),
);

class AddProductSheet extends ConsumerStatefulWidget {
  const AddProductSheet({super.key, this.location, this.queue = const [], this.onAdded});

  final StorageLocation? location;
  final List<String> queue;
  final ValueChanged<String>? onAdded;

  @override
  ConsumerState<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<AddProductSheet> {
  final _name = TextEditingController();
  final _focus = FocusNode();
  final _added = <String>[];
  late final List<String> _queue = [...widget.queue];

  DateTime? _exp;
  bool _expTouched = false;
  int? _suggestedDays;
  late StorageLocation _location;
  int _quantity = 1;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _location =
        widget.location ?? StorageLocation.parse(ref.read(preferencesProvider).getString(PreferenceKeys.lastLocation));
    _name.addListener(_onNameChanged);
    if (_queue.isNotEmpty) _prefill(_queue.removeAt(0));
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<ProductSuggestion> get _suggestions => ref.read(suggestionsProvider).value ?? const [];

  void _onNameChanged() {
    final exact = exactSuggestion(_suggestions, parseQuickEntry(_name.text).name);
    final days = exact?.shelfDays;
    if (days == _suggestedDays) {
      setState(() {});
      return;
    }
    setState(() {
      _suggestedDays = days;
      if (!_expTouched) _exp = days == null ? null : addDays(today(), days);
      if (exact != null && !_expTouched) _location = exact.location;
    });
  }

  void _prefill(String name) {
    _name.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
  }

  void _applySuggestion(ProductSuggestion suggestion) {
    _expTouched = false;
    _prefill(suggestion.name);
    _focus.requestFocus();
  }

  void _setExp(DateTime value) => setState(() {
    _exp = value;
    _expTouched = true;
    _error = null;
  });

  Future<void> _submit() async {
    if (_busy) return;
    final entry = parseQuickEntry(_name.text);
    if (entry.name.isEmpty) {
      _focus.requestFocus();
      return;
    }
    final exp = entry.exp ?? _exp;
    if (exp == null) {
      setState(() => _error = 'Choisissez une date de péremption');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(productsProvider.notifier)
          .add(ProductDraft(name: entry.name, exp: exp, quantity: _quantity, location: _location));
      await ref.read(preferencesProvider).setString(PreferenceKeys.lastLocation, _location.value);
      widget.onAdded?.call(entry.name);
      if (!mounted) return;
      setState(() {
        _added.add(entry.name);
        _exp = null;
        _expTouched = false;
        _suggestedDays = null;
        _quantity = 1;
        _error = null;
      });
      _name.clear();
      if (_queue.isNotEmpty) _prefill(_queue.removeAt(0));
      _focus.requestFocus();
    } catch (error) {
      if (mounted) setState(() => _error = 'Ajout impossible : $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(suggestionsProvider);
    final query = parseQuickEntry(_name.text).name;
    final suggestions = rankSuggestions(_suggestions, query, limit: 6);
    final inlineDate = parseQuickEntry(_name.text).exp;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(switch (_location) {
                  StorageLocation.fridge => 'Ajouter au frigo',
                  StorageLocation.freezer => 'Ajouter au congélo',
                  StorageLocation.pantry => 'Ajouter au placard',
                }, style: theme.textTheme.titleLarge),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Terminé')),
            ],
          ),
          if (_added.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in _added.reversed.take(6))
                  Chip(
                    avatar: const Icon(Icons.check, size: 16),
                    label: Text(name),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          TextField(
            controller: _name,
            focusNode: _focus,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onEditingComplete: () {},
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: _queue.isEmpty && widget.queue.isEmpty ? 'Produit' : 'Produit (${_queue.length} restants)',
              hintText: 'ex. yaourts 12/11',
            ),
          ),
          if (suggestions.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  for (final suggestion in suggestions)
                    ActionChip(
                      avatar: const Icon(Icons.history, size: 18),
                      label: Text(
                        suggestion.shelfDays == null
                            ? suggestion.name
                            : '${suggestion.name} · ${suggestion.shelfDays} j',
                      ),
                      onPressed: () => _applySuggestion(suggestion),
                    ),
                ],
              ),
            ),
          ExpiryPicker(
            value: inlineDate ?? _exp,
            location: _location,
            suggestedDays: _suggestedDays,
            onChanged: _setExp,
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: LocationSelector(value: _location, onChanged: (value) => setState(() => _location = value)),
              ),
              QuantityStepper(value: _quantity, onChanged: (value) => setState(() => _quantity = value)),
            ],
          ),
          if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Ajouter'),
          ),
          Text(
            'Astuce : « yaourts 12/11 », « jambon 15 novembre » ou « poulet +3 » règlent la date',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
