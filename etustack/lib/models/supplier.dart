class Supplier {
  int? id;
  String name;
  String? company;
  String? description;
  String? phone;
  String? email;
  String? address;
  String? notes;
  double balance;

  Supplier({
    this.id,
    required this.name,
    this.company,
    this.description,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.balance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'description': description,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'balance': balance,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      company: map['company'],
      description: map['description'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      notes: map['notes'],
      balance: map['balance'] != null ? (map['balance'] as num).toDouble() : 0.0,
    );
  }
}
