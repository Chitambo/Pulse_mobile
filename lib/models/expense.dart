class Expense {
  final int id;
  final String expenseNumber;
  final String date;
  final String category;
  final String payee;
  final String? description;
  final double amount;
  final double vatAmount;
  final double totalAmount;
  final String paymentMethod;
  final String? reference;
  final String status;
  final String? voucherNumber;
  final String? paidDate;
  final String? rejectionReason;
  final String? submittedByName;

  Expense({
    required this.id,
    required this.expenseNumber,
    required this.date,
    required this.category,
    required this.payee,
    this.description,
    required this.amount,
    required this.vatAmount,
    required this.totalAmount,
    required this.paymentMethod,
    this.reference,
    required this.status,
    this.voucherNumber,
    this.paidDate,
    this.rejectionReason,
    this.submittedByName,
  });

  static String? _name(Map<String, dynamic>? sb) {
    if (sb == null) return null;
    final emp = sb['employee'];
    if (emp != null) return '${emp['firstName']} ${emp['lastName']}';
    return sb['username'];
  }

  static double _d(dynamic v) => double.tryParse('${v ?? 0}') ?? 0;

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'],
        expenseNumber: j['expenseNumber'] ?? 'EXP-${j['id']}',
        date: j['date'] ?? '',
        category: j['category'] ?? 'other',
        payee: j['payee'] ?? '',
        description: j['description'],
        amount: _d(j['amount']),
        vatAmount: _d(j['vatAmount']),
        totalAmount: _d(j['totalAmount']),
        paymentMethod: j['paymentMethod'] ?? 'cash',
        reference: j['reference'],
        status: j['status'] ?? 'pending',
        voucherNumber: j['voucherNumber'],
        paidDate: j['paidDate'],
        rejectionReason: j['rejectionReason'],
        submittedByName: _name(j['submittedBy'] as Map<String, dynamic>?),
      );
}

const expenseCategories = [
  'salary_advance', 'office_rent', 'utilities', 'transport', 'equipment',
  'software_tools', 'training', 'marketing', 'bank_charges', 'stationery',
  'maintenance', 'entertainment', 'other',
];
