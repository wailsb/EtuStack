class Product {
  int? id;
  String? barcode;
  String name;
  String? description;
  int quantity;
  double? buyPrice;
  double? sellPrice;
  int? categoryId;
  int? supplierId;

  Product({
    this.id,
    this.barcode,
    required this.name,
    this.description,
    this.quantity = 0,
    this.buyPrice,
    this.sellPrice,
    this.categoryId,
    this.supplierId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'description': description,
      'quantity': quantity,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'category_id': categoryId,
      'supplier_id': supplierId,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      barcode: map['barcode'],
      name: map['name'],
      description: map['description'],
      quantity: map['quantity'] ?? 0,
      buyPrice: map['buy_price'] != null ? map['buy_price'].toDouble() : null,
      sellPrice: map['sell_price'] != null ? map['sell_price'].toDouble() : null,
      categoryId: map['category_id'],
      supplierId: map['supplier_id'],
    );
  }

  double? get profit {
    if (buyPrice != null && sellPrice != null) {
      return sellPrice! - buyPrice!;
    }
    return null;
  }

  double? get profitMargin {
    if (buyPrice != null && sellPrice != null && buyPrice! > 0) {
      return (sellPrice! - buyPrice!) / buyPrice! * 100;
    }
    return null;
  }
}
