class Supplier {
  int? id;
  String name;
  String? company;
  String? description;
  String? phone;

  Supplier({
    this.id,
    required this.name,
    this.company,
    this.description,
    this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'description': description,
      'phone': phone,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      company: map['company'],
      description: map['description'],
      phone: map['phone'],
    );
  }
}
