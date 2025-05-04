class CartItem {
  int? id;
  int cartId;
  int productId;
  int quantity;
  double priceAtSale;

  CartItem({
    this.id,
    required this.cartId,
    required this.productId,
    required this.quantity,
    required this.priceAtSale,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cart_id': cartId,
      'product_id': productId,
      'quantity': quantity,
      'price_at_sale': priceAtSale,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      cartId: map['cart_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      priceAtSale: map['price_at_sale'].toDouble(),
    );
  }

  double get total => quantity * priceAtSale;
}
