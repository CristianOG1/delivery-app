class Restaurant {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? category;
  final double rating;
  final String? address;
  final bool isOpen;

  Restaurant({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.category,
    this.rating = 0,
    this.address,
    this.isOpen = true,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      category: map['category'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      address: map['address'] as String?,
      isOpen: map['is_open'] as bool? ?? true,
    );
  }
}