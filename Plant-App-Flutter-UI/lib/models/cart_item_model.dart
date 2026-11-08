class CartItem {
  final String productId;
  final String name;
  final double price;
  final String imageUrl;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.imageUrl = '',
    this.quantity = 1,
  });

  void incrementQuantity() {
    quantity++;
  }

  void decrementQuantity() {
    if (quantity > 1) {
      quantity--;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: (json['productId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: double.tryParse((json['price'] ?? 0).toString()) ?? 0.0,
      imageUrl: (json['imageUrl'] ?? '').toString(),
      quantity: int.tryParse((json['quantity'] ?? 1).toString()) ?? 1,
    );
  }
}
