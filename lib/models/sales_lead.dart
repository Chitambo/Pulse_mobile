import 'employee.dart';
import 'client.dart';

class SalesLead {
  final int id;
  final String leadSource;
  final String productOfInterest;
  final String stage;
  final String probability;
  final String? prospectName;
  final String? contactPerson;
  final String? contactPhone;
  final String? contactEmail;
  final double? estimatedValue;
  final String? nextFollowUpDate;
  final String? notes;
  final int? clientId;
  final int? assignedOfficerId;
  final Client? client;
  final Employee? assignedOfficer;
  final String createdAt;

  SalesLead({
    required this.id,
    required this.leadSource,
    required this.productOfInterest,
    required this.stage,
    required this.probability,
    this.prospectName,
    this.contactPerson,
    this.contactPhone,
    this.contactEmail,
    this.estimatedValue,
    this.nextFollowUpDate,
    this.notes,
    this.clientId,
    this.assignedOfficerId,
    this.client,
    this.assignedOfficer,
    required this.createdAt,
  });

  factory SalesLead.fromJson(Map<String, dynamic> j) => SalesLead(
        id: j['id'],
        leadSource: j['leadSource'] ?? '',
        productOfInterest: j['productOfInterest'] ?? '',
        stage: j['stage'] ?? 'new',
        probability: j['probability'] ?? 'medium',
        prospectName: j['prospectName'],
        contactPerson: j['contactPerson'],
        contactPhone: j['contactPhone'],
        contactEmail: j['contactEmail'],
        estimatedValue: j['estimatedValue'] != null
            ? double.tryParse(j['estimatedValue'].toString())
            : null,
        nextFollowUpDate: j['nextFollowUpDate'],
        notes: j['notes'],
        clientId: j['clientId'],
        assignedOfficerId: j['assignedOfficerId'],
        client: j['client'] != null ? Client.fromJson(j['client']) : null,
        assignedOfficer: j['assignedOfficer'] != null
            ? Employee.fromJson(j['assignedOfficer'])
            : null,
        createdAt: j['createdAt'] ?? '',
      );
}
