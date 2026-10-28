import '../../../core/text.dart';
import 'product.dart';

class ProductSuggestion {
  ProductSuggestion({
    required this.name,
    required this.uses,
    required this.shelfDays,
    required this.location,
    required this.lastAddedAt,
  }) : searchKey = normalizeText(name);

  factory ProductSuggestion.fromJson(Map<String, dynamic> json) => ProductSuggestion(
    name: json['name'] as String,
    uses: (json['uses'] as num?)?.toInt() ?? 1,
    shelfDays: (json['shelf_days'] as num?)?.toInt(),
    location: StorageLocation.parse(json['location'] as String?),
    lastAddedAt: DateTime.tryParse(json['last_added_at'] as String? ?? '')?.toLocal(),
  );

  final String name;
  final int uses;
  final int? shelfDays;
  final StorageLocation location;
  final DateTime? lastAddedAt;
  final String searchKey;
}

List<ProductSuggestion> rankSuggestions(List<ProductSuggestion> all, String query, {int limit = 8}) {
  final key = normalizeText(query);
  if (key.isEmpty) {
    final recent = [...all]
      ..sort((a, b) {
        final byUses = b.uses.compareTo(a.uses);
        if (byUses != 0) return byUses;
        return (b.lastAddedAt ?? DateTime(0)).compareTo(a.lastAddedAt ?? DateTime(0));
      });
    return recent.take(limit).toList();
  }
  final prefix = <ProductSuggestion>[];
  final contains = <ProductSuggestion>[];
  for (final suggestion in all) {
    if (suggestion.searchKey == key) continue;
    if (suggestion.searchKey.startsWith(key)) {
      prefix.add(suggestion);
    } else if (suggestion.searchKey.contains(key)) {
      contains.add(suggestion);
    }
  }
  return [...prefix, ...contains].take(limit).toList();
}

ProductSuggestion? exactSuggestion(List<ProductSuggestion> all, String name) {
  final key = normalizeText(name);
  if (key.isEmpty) return null;
  for (final suggestion in all) {
    if (suggestion.searchKey == key) return suggestion;
  }
  return null;
}
