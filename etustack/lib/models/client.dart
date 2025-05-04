class Client {
  int? id;
  String name;
  String? description;
  String? phone;
  int points;

  Client({
    this.id,
    required this.name,
    this.description,
    this.phone,
    this.points = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'phone': phone,
      'points': points,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      phone: map['phone'],
      points: map['points'] ?? 0,
    );
  }
}
