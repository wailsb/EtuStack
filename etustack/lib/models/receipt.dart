class Receipt {
  int? id;
  DateTime date;
  int? clientId;
  String? company;
  double totalAmount;
  String status; // 'pending', 'completed', 'cancelled'

  Receipt({
    this.id,
    required this.date,
    this.clientId,
    this.company,
    this.totalAmount = 0.0,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'client_id': clientId,
      'company': company,
      'total_amount': totalAmount,
      'status': status,
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'],
      date: DateTime.parse(map['date']),
      clientId: map['client_id'],
      company: map['company'],
      totalAmount: map['total_amount'] != null ? map['total_amount'].toDouble() : 0.0,
      status: map['status'] ?? 'pending',
    );
  }
}
