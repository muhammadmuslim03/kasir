class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sellingPrice,
    required this.costPrice,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int sellingPrice;
  final int costPrice;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasImage => imageUrl.trim().isNotEmpty;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      sellingPrice: json['selling_price'] as int,
      costPrice: json['cost_price'] as int,
      imageUrl: json['image_url'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProductInput {
  const ProductInput({
    required this.name,
    required this.sellingPrice,
    required this.costPrice,
    required this.imageUrl,
  });

  final String name;
  final int sellingPrice;
  final int costPrice;
  final String imageUrl;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'image_url': imageUrl,
    };
  }
}
