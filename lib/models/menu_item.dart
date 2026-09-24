class MenuItem {
  final String id;
  final String restaurantId;
  final String? restaurantName;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final String? category;
  final bool isAvailable;
  final bool isFeatured;

  MenuItem({
    required this.id,
    required this.restaurantId,
    this.restaurantName,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.category,
    this.isAvailable = true,
    this.isFeatured = false,
  });

  /// El '*, restaurants(name)' en la consulta de Supabase hace que venga
  /// un mapa anidado 'restaurants': {'name': ...} junto con el platillo.
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    final restaurantData = map['restaurants'] as Map<String, dynamic>?;

    return MenuItem(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      restaurantName: restaurantData?['name'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      imageUrl: map['image_url'] as String?,
      category: map['category'] as String?,
      isAvailable: map['is_available'] as bool? ?? true,
      isFeatured: map['is_featured'] as bool? ?? false,
    );
  }
}