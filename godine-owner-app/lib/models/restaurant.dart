class Restaurant {
  final String id;
  final String name;
  final String slug;
  final String ownerPassword;
  final int totalTables;
  final bool isActive;
  final int sortOrder;
  final String createdAt;
  final bool isTrial;
  final DateTime? subscriptionEnd;
  final String? announcement;
  final DateTime? trialEndsAt;
  final bool isVerified;
  final String plan;
  final String planStatus;
  final int physicalQrCount;
  final String? razorpayPaymentId;
  final String? deliveryAddress;
  final String? deliveryPincode;
  final String? deliveryPhone;

  Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.ownerPassword,
    required this.totalTables,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    this.isTrial = true,
    this.subscriptionEnd,
    this.announcement,
    this.trialEndsAt,
    this.isVerified = false,
    this.plan = 'trial',
    this.planStatus = 'active',
    this.physicalQrCount = 0,
    this.razorpayPaymentId,
    this.deliveryAddress,
    this.deliveryPincode,
    this.deliveryPhone,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      slug: (json['slug'] ?? '') as String,
      ownerPassword: (json['owner_password'] ?? '') as String,
      totalTables: (json['total_tables'] as num?)?.toInt() ?? 10,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      isTrial: json['is_trial'] as bool? ?? true,
      subscriptionEnd: json['subscription_end'] != null 
          ? DateTime.tryParse(json['subscription_end'] as String) 
          : null,
      announcement: json['announcement'] as String?,
      trialEndsAt: json['trial_ends_at'] != null 
          ? DateTime.tryParse(json['trial_ends_at'] as String) 
          : null,
      isVerified: json['is_verified'] as bool? ?? false,
      plan: json['plan'] as String? ?? 'trial',
      planStatus: json['plan_status'] as String? ?? 'active',
      physicalQrCount: (json['physical_qr_count'] as num?)?.toInt() ?? 0,
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      deliveryPincode: json['delivery_pincode'] as String?,
      deliveryPhone: json['delivery_phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'owner_password': ownerPassword,
        'total_tables': totalTables,
        'is_active': isActive,
        'sort_order': sortOrder,
        'is_trial': isTrial,
        'subscription_end': subscriptionEnd?.toIso8601String(),
        'announcement': announcement,
        'trial_ends_at': trialEndsAt?.toIso8601String(),
        'is_verified': isVerified,
        'plan': plan,
        'plan_status': planStatus,
        'physical_qr_count': physicalQrCount,
        'razorpay_payment_id': razorpayPaymentId,
        'delivery_address': deliveryAddress,
        'delivery_pincode': deliveryPincode,
        'delivery_phone': deliveryPhone,
      };
}
