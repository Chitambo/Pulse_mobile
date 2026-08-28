class Quotation {
  final int id;
  final String quotationNumber;
  final String? prospectName;
  final String issueDate;
  final String expiryDate;
  final double subTotal;
  final double vatAmount;
  final double totalAmount;
  final String status;
  final String? notes;
  final String? clientName;
  final String? preparedByName;

  Quotation({
    required this.id,
    required this.quotationNumber,
    this.prospectName,
    required this.issueDate,
    required this.expiryDate,
    required this.subTotal,
    required this.vatAmount,
    required this.totalAmount,
    required this.status,
    this.notes,
    this.clientName,
    this.preparedByName,
  });

  static double _d(dynamic v) => double.tryParse('${v ?? 0}') ?? 0;

  static String? _name(Map<String, dynamic>? p) {
    if (p == null) return null;
    if (p['firstName'] != null) return '${p['firstName']} ${p['lastName']}';
    return p['name'] ?? p['username'];
  }

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        id: j['id'],
        quotationNumber: j['quotationNumber'] ?? 'QUO-${j['id']}',
        prospectName: j['prospectName'],
        issueDate: j['issueDate'] ?? '',
        expiryDate: j['expiryDate'] ?? '',
        subTotal: _d(j['subTotal']),
        vatAmount: _d(j['vatAmount']),
        totalAmount: _d(j['totalAmount']),
        status: j['status'] ?? 'draft',
        notes: j['notes'],
        clientName: _name(j['client'] as Map<String, dynamic>?),
        preparedByName: _name(j['preparedBy'] as Map<String, dynamic>?),
      );
}
