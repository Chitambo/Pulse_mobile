class Client {
  final int id;
  final String clientCode;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? industry;
  final String supportLevel;
  final String? supportExpiryDate;
  final bool isActive;
  final String? notes;

  Client({
    required this.id,
    required this.clientCode,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.industry,
    required this.supportLevel,
    this.supportExpiryDate,
    required this.isActive,
    this.notes,
  });

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: j['id'],
        clientCode: j['clientCode'] ?? '',
        name: j['name'] ?? '',
        contactPerson: j['contactPerson'],
        phone: j['phone'],
        email: j['email'],
        address: j['address'],
        industry: j['industry'],
        supportLevel: j['supportLevel'] ?? 'none',
        supportExpiryDate: j['supportExpiryDate'],
        isActive: j['isActive'] ?? true,
        notes: j['notes'],
      );
}
