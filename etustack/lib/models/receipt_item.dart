class ReceiptItem {
  int? id;
  int receiptId;
  int productId;
  int quantity;
  double price;

  ReceiptItem({
    this.id,
    required this.receiptId,
    required this.productId,
    required this.quantity,
    required this.price,
  });

  // Calculate the total price for this item
  double get total => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receipt_id': receiptId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
    };
  }

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      id: map['id'],
      receiptId: map['receipt_id'],
      productId: map['product_id'],
      quantity: map['quantity'] ?? 1,
      price: map['price'] != null ? (map['price'] as num).toDouble() : 0.0,
    );
  }
}
