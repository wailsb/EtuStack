class Client {
  int? id;
  String name;
  String? description;
  String? phone;
  String? email;
  String? address;
  String? company;
  double balance;
  String? notes;
  int points;

  Client({
    this.id,
    required this.name,
    this.description,
    this.phone,
    this.email,
    this.address,
    this.company,
    this.balance = 0.0,
    this.notes,
    this.points = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'phone': phone,
      'email': email,
      'address': address,
      'company': company,
      'balance': balance,
      'notes': notes,
      'points': points,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      company: map['company'],
      balance: map['balance'] != null ? (map['balance'] as num).toDouble() : 0.0,
      notes: map['notes'],
      points: map['points'] ?? 0,
    );
  }
}
