/// GoDine — Inventory Item Model
/// Maps to the `inventory_items` table in Supabase.

class InventoryItem {
  final String id;
  final String restaurantId;
  final String name;
  final String unit;
  final double quantity;
  final double lowStockThreshold;
  final double? costPrice;
  final DateTime? lastLowStockNotifiedAt;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  InventoryItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.lowStockThreshold,
    this.costPrice,
    this.lastLowStockNotifiedAt,
    this.updatedAt,
    this.createdAt,
  });

  /// Stock status based on quantity vs threshold.
  String get stockStatus {
    if (quantity <= 0) return 'out';
    if (quantity <= lowStockThreshold) return 'low';
    return 'ok';
  }

  bool get isLowStock => quantity <= lowStockThreshold && quantity > 0;
  bool get isOutOfStock => quantity <= 0;
  bool get isInStock => quantity > lowStockThreshold;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      restaurantId: json['restaurant_id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toDouble() ?? 5,
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      lastLowStockNotifiedAt: json['last_low_stock_notified_at'] != null
          ? DateTime.tryParse(json['last_low_stock_notified_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'restaurant_id': restaurantId,
    'name': name,
    'unit': unit,
    'quantity': quantity,
    'low_stock_threshold': lowStockThreshold,
    if (costPrice != null) 'cost_price': costPrice,
  };

  InventoryItem copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? unit,
    double? quantity,
    double? lowStockThreshold,
    double? costPrice,
    DateTime? lastLowStockNotifiedAt,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      costPrice: costPrice ?? this.costPrice,
      lastLowStockNotifiedAt: lastLowStockNotifiedAt ?? this.lastLowStockNotifiedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
