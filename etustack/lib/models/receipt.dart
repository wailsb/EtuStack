class Receipt {
  int? id;
  DateTime date;
  int? clientId;
  int? supplierId;
  String type; // 'sale', 'purchase', 'return', etc.
  double totalAmount;
  String? paymentMethod;
  String? referenceNumber;
  String? notes;
  String status; // 'pending', 'completed', 'cancelled'

  Receipt({
    this.id,
    required this.date,
    this.clientId,
    this.supplierId,
    required this.type,
    this.totalAmount = 0.0,
    this.paymentMethod,
    this.referenceNumber,
    this.notes,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'client_id': clientId,
      'supplier_id': supplierId,
      'type': type,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'notes': notes,
      'status': status,
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'],
      date: map['date'] is String ? DateTime.parse(map['date']) : map['date'] as DateTime,
      clientId: map['client_id'],
      supplierId: map['supplier_id'],
      type: map['type'] ?? 'sale',
      totalAmount: map['total_amount'] != null ? (map['total_amount'] as num).toDouble() : 0.0,
      paymentMethod: map['payment_method'],
      referenceNumber: map['reference_number'],
      notes: map['notes'],
      status: map['status'] ?? 'pending',
    );
  }
}
