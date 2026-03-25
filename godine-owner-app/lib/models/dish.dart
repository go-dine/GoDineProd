class Dish {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String category;
  final String emoji;
  final bool available;
  final String createdAt;

  Dish({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description = '',
    required this.price,
    this.category = 'Main Course',
    this.emoji = '🍽️',
    this.available = true,
    this.createdAt = '',
  });

  factory Dish.fromJson(Map<String, dynamic> json) {
    return Dish(
      id: json['id'] as String,
      restaurantId: json['restaurant_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String? ?? 'Main Course',
      emoji: json['emoji'] as String? ?? '🍽️',
      available: json['available'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Dish copyWith({bool? available}) {
    return Dish(
      id: id,
      restaurantId: restaurantId,
      name: name,
      description: description,
      price: price,
      category: category,
      emoji: emoji,
      available: available ?? this.available,
      createdAt: createdAt,
    );
  }
}
