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
      };
}
