class FeedbackModel {
  final String id;
  final String restaurantId;
  final String? orderId;
  final int foodRating;
  final int serviceRating;
  final String? comment;
  final String? customerName;
  final String? customerPhone;
  final String createdAt;
  final String? restaurantName;

  FeedbackModel({
    required this.id,
    required this.restaurantId,
    this.orderId,
    required this.foodRating,
    required this.serviceRating,
    this.comment,
    this.customerName,
    this.customerPhone,
    required this.createdAt,
    this.restaurantName,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'],
      restaurantId: json['restaurant_id'],
      orderId: json['order_id'],
      foodRating: json['food_rating'] ?? 0,
      serviceRating: json['service_rating'] ?? 0,
      comment: json['comment'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      createdAt: json['created_at'],
      restaurantName: json['restaurants']?['name'],
    );
  }

  double get averageRating => (foodRating + serviceRating) / 2.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'order_id': orderId,
      'food_rating': foodRating,
      'service_rating': serviceRating,
      'comment': comment,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'created_at': createdAt,
    };
  }
}
