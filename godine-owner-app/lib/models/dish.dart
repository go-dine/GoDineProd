class Dish {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String category;
  final String emoji;
  final String? imageUrl;
  final bool available;
  final bool isFeatured;
  final String createdAt;

  Dish({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description = '',
    required this.price,
    this.category = 'Main Course',
    this.emoji = '🍽️',
    this.imageUrl,
    this.available = true,
    this.isFeatured = false,
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
      imageUrl: json['image_url'] as String?,
      available: json['available'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Dish copyWith({bool? available, bool? isFeatured}) {
    return Dish(
      id: id,
      restaurantId: restaurantId,
      name: name,
      description: description,
      price: price,
      category: category,
      emoji: emoji,
      imageUrl: imageUrl,
      available: available ?? this.available,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt,
    );
  }
}
