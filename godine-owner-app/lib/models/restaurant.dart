class Restaurant {
  final String id;
  final String name;
  final String slug;
  final String ownerPassword;
  final int totalTables;
  final String createdAt;

  Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.ownerPassword,
    required this.totalTables,
    required this.createdAt,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      ownerPassword: json['owner_password'] as String,
      totalTables: (json['total_tables'] as num?)?.toInt() ?? 10,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'owner_password': ownerPassword,
        'total_tables': totalTables,
      };
}
