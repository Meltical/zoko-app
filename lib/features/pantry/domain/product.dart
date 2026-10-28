import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import 'expiry.dart';

enum StorageLocation {
  fridge('fridge', 'Frigo', Icons.kitchen_outlined),
  freezer('freezer', 'Congélo', Icons.ac_unit),
  pantry('pantry', 'Placard', Icons.shelves);

  const StorageLocation(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static StorageLocation parse(String? value) =>
      values.firstWhere((location) => location.value == value, orElse: () => fridge);
}

enum ConsumptionOutcome {
  eaten('eaten'),
  wasted('wasted');

  const ConsumptionOutcome(this.value);

  final String value;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.exp,
    required this.quantity,
    required this.location,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: (json['id'] as num).toInt(),
    name: (json['name'] as String).trim(),
    exp: parseDbDate(json['exp'] as String),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    location: StorageLocation.parse(json['location'] as String?),
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  final int id;
  final String name;
  final DateTime exp;
  final int quantity;
  final StorageLocation location;
  final DateTime createdAt;

  Expiry get expiry => Expiry(exp);

  Product copyWith({String? name, DateTime? exp, int? quantity, StorageLocation? location}) => Product(
    id: id,
    name: name ?? this.name,
    exp: exp ?? this.exp,
    quantity: quantity ?? this.quantity,
    location: location ?? this.location,
    createdAt: createdAt,
  );

  ProductDraft toDraft() =>
      ProductDraft(name: name, exp: exp, quantity: quantity, location: location, createdAt: createdAt);
}

class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.exp,
    this.quantity = 1,
    this.location = StorageLocation.fridge,
    this.createdAt,
  });

  final String name;
  final DateTime exp;
  final int quantity;
  final StorageLocation location;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'exp': formatDbDate(exp),
    'quantity': quantity,
    'location': location.value,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
  };
}

int compareByExpiry(Product a, Product b) {
  final byDate = a.exp.compareTo(b.exp);
  return byDate != 0 ? byDate : a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
