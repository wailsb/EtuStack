class ReceiptItem {
  int? id;
  int receiptId;
  int productId;
  int quantity;
  double priceAtSale;
  double total;

  ReceiptItem({
    this.id,
    required this.receiptId,
    required this.productId,
    required this.quantity,
    required this.priceAtSale,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receipt_id': receiptId,
      'product_id': productId,
      'quantity': quantity,
      'price_at_sale': priceAtSale,
      'total': total,
    };
  }

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      id: map['id'],
      receiptId: map['receipt_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      priceAtSale: map['price_at_sale'] != null ? map['price_at_sale'].toDouble() : 0.0,
      total: map['total'] != null ? map['total'].toDouble() : 0.0,
    );
  }
}
