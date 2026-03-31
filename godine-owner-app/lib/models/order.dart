class OrderItem {
  final String name;
  final int qty;
  final double price;
  final String emoji;

  OrderItem({
    required this.name,
    required this.qty,
    required this.price,
    this.emoji = '🍽',
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String,
      qty: (json['qty'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      emoji: json['emoji'] as String? ?? '🍽',
    );
  }
}

class Order {
  final String id;
  final String restaurantId;
  final String tableNumber;
  final String? customerName;
  final String? customerPhone;
  final String? customerUid;
  final List<OrderItem> items;
  final double total;
  final String status; // pending | preparing | ready | completed
  final String note;
  final String? tokenNumber;
  final String? estimatedTime;
  final String createdAt;
  final bool billSent;

  Order({
    required this.id,
    required this.restaurantId,
    required this.tableNumber,
    this.customerName,
    this.customerPhone,
    this.customerUid,
    required this.items,
    required this.total,
    this.status = 'pending',
    this.note = '',
    this.tokenNumber,
    this.estimatedTime,
    required this.createdAt,
    this.billSent = false,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return Order(
      id: json['id'] as String,
      restaurantId: json['restaurant_id'] as String,
      tableNumber: json['table_number'] as String,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerUid: json['customer_uid'] as String?,
      items: itemsList.map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList(),
      total: (json['total'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      note: json['note'] as String? ?? '',
      tokenNumber: json['token_number'] as String?,
      estimatedTime: json['estimated_time'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      billSent: json['bill_sent'] == true,
    );
  }

  Order copyWith({String? status, String? estimatedTime, String? tokenNumber, bool? billSent}) {
    return Order(
      id: id,
      restaurantId: restaurantId,
      tableNumber: tableNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      customerUid: customerUid,
      items: items,
      total: total,
      status: status ?? this.status,
      note: note,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      createdAt: createdAt,
      billSent: billSent ?? this.billSent,
    );
  }
}
