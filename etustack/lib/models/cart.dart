import 'package:intl/intl.dart';

class Cart {
  int? id;
  DateTime date;
  int? clientId;
  double totalAmount;

  Cart({
    this.id,
    required this.date,
    this.clientId,
    this.totalAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(date),
      'client_id': clientId,
      'total_amount': totalAmount,
    };
  }

  factory Cart.fromMap(Map<String, dynamic> map) {
    return Cart(
      id: map['id'],
      date: map['date'] != null 
        ? DateFormat('yyyy-MM-dd HH:mm:ss').parse(map['date'])
        : DateTime.now(),
      clientId: map['client_id'],
      totalAmount: map['total_amount'] != null ? map['total_amount'].toDouble() : 0.0,
    );
  }
}
