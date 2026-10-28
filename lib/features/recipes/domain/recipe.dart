class Ingredient {
  const Ingredient({required this.key, required this.name, required this.aliases, required this.staple});

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    key: json['key'] as String,
    name: json['name'] as String,
    aliases: List<String>.from(json['aliases'] as List? ?? const []),
    staple: json['staple'] as bool? ?? false,
  );

  final String key;
  final String name;
  final List<String> aliases;
  final bool staple;
}

class RecipeIngredient {
  const RecipeIngredient({required this.key, required this.label, this.alternatives = const [], this.optional = false});

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
    key: json['key'] as String,
    label: json['label'] as String,
    alternatives: List<String>.from(json['alt'] as List? ?? const []),
    optional: json['optional'] as bool? ?? false,
  );

  final String key;
  final String label;
  final List<String> alternatives;
  final bool optional;

  Iterable<String> get keys => [key, ...alternatives];
}

class Recipe {
  const Recipe({
    required this.slug,
    required this.title,
    required this.ingredients,
    required this.steps,
    this.imageUrl,
    this.imageCredit,
    this.imageSource,
    this.prepMinutes,
    this.cookMinutes,
    this.servings,
    this.difficulty,
    this.tags = const [],
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    slug: json['slug'] as String,
    title: json['title'] as String,
    imageUrl: json['image_url'] as String?,
    imageCredit: json['image_credit'] as String?,
    imageSource: json['image_source'] as String?,
    prepMinutes: (json['prep_minutes'] as num?)?.toInt(),
    cookMinutes: (json['cook_minutes'] as num?)?.toInt(),
    servings: (json['servings'] as num?)?.toInt(),
    difficulty: json['difficulty'] as String?,
    tags: List<String>.from(json['tags'] as List? ?? const []),
    ingredients: [
      for (final item in json['ingredients'] as List) RecipeIngredient.fromJson(item as Map<String, dynamic>),
    ],
    steps: List<String>.from(json['steps'] as List),
  );

  final String slug;
  final String title;
  final String? imageUrl;
  final String? imageCredit;
  final String? imageSource;
  final int? prepMinutes;
  final int? cookMinutes;
  final int? servings;
  final String? difficulty;
  final List<String> tags;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;

  int? get totalMinutes => prepMinutes == null && cookMinutes == null ? null : (prepMinutes ?? 0) + (cookMinutes ?? 0);
}
