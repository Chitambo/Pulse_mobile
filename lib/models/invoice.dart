import 'client.dart';
import 'employee.dart';

class Payment {
  final int id;
  final String paymentDate;
  final double amount;
  final String? paymentMethod;
  final String? reference;
  final String? notes;

  Payment({
    required this.id,
    required this.paymentDate,
    required this.amount,
    this.paymentMethod,
    this.reference,
    this.notes,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'],
        paymentDate: j['paymentDate'] ?? '',
        amount: double.tryParse(j['amount'].toString()) ?? 0,
        paymentMethod: j['paymentMethod'],
        reference: j['reference'],
        notes: j['notes'],
      );
}

class Invoice {
  final int id;
  final String invoiceNumber;
  final String serviceType;
  final double amountBeforeVat;
  final double vatAmount;
  final double totalAmount;
  final double amountPaid;
  final double balance;
  final String paymentStatus;
  final String dueDate;
  final String? description;
  final String? followUpNotes;
  final String? nextFollowUpDate;
  final double vatRate;
  final int? clientId;
  final int? responsibleOfficerId;
  final Client? client;
  final Employee? responsibleOfficer;
  final List<Payment> payments;
  final String createdAt;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.serviceType,
    required this.amountBeforeVat,
    required this.vatAmount,
    required this.totalAmount,
    required this.amountPaid,
    required this.balance,
    required this.paymentStatus,
    required this.dueDate,
    this.description,
    this.followUpNotes,
    this.nextFollowUpDate,
    required this.vatRate,
    this.clientId,
    this.responsibleOfficerId,
    this.client,
    this.responsibleOfficer,
    required this.payments,
    required this.createdAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        id: j['id'],
        invoiceNumber: j['invoiceNumber'] ?? 'INV-${j['id']}',
        serviceType: j['serviceType'] ?? '',
        amountBeforeVat: double.tryParse(j['amountBeforeVat'].toString()) ?? 0,
        vatAmount: double.tryParse(j['vatAmount']?.toString() ?? '0') ?? 0,
        totalAmount: double.tryParse(j['totalAmount']?.toString() ?? '0') ?? 0,
        amountPaid: double.tryParse(j['amountPaid']?.toString() ?? '0') ?? 0,
        balance: double.tryParse(j['balance']?.toString() ?? '0') ?? 0,
        paymentStatus: j['paymentStatus'] ?? 'unpaid',
        dueDate: j['dueDate'] ?? '',
        description: j['description'],
        followUpNotes: j['followUpNotes'],
        nextFollowUpDate: j['nextFollowUpDate'],
        vatRate: double.tryParse(j['vatRate']?.toString() ?? '16') ?? 16,
        clientId: j['clientId'],
        responsibleOfficerId: j['responsibleOfficerId'],
        client: j['client'] != null ? Client.fromJson(j['client']) : null,
        responsibleOfficer: j['responsibleOfficer'] != null
            ? Employee.fromJson(j['responsibleOfficer'])
            : null,
        payments: (j['payments'] as List? ?? []).map((p) => Payment.fromJson(p)).toList(),
        createdAt: j['createdAt'] ?? '',
      );
}
