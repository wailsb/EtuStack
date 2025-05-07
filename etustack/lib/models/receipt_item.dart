class ReceiptItem {
  int? id;
  int receiptId;
  int productId;
  int quantity;
  double priceAtSale;

  ReceiptItem({
    this.id,
    required this.receiptId,
    required this.productId,
    required this.quantity,
    required this.priceAtSale,
  });

  // Calculate the total price for this item
  double get total => priceAtSale * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receipt_id': receiptId,
      'product_id': productId,
      'quantity': quantity,
      'price_at_sale': priceAtSale,
    };
  }

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      id: map['id'],
      receiptId: map['receipt_id'],
      productId: map['product_id'],
      quantity: map['quantity'] ?? 1,
      priceAtSale: map['price_at_sale'] != null ? (map['price_at_sale'] as num).toDouble() : 0.0,
    );
  }
}
