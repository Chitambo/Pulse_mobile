import 'client.dart';
import 'employee.dart';

class TicketUpdate {
  final int id;
  final String? comment;
  final String? status;
  final String createdAt;
  final String? updatedBy;

  TicketUpdate({
    required this.id,
    this.comment,
    this.status,
    required this.createdAt,
    this.updatedBy,
  });

  factory TicketUpdate.fromJson(Map<String, dynamic> j) => TicketUpdate(
        id: j['id'],
        comment: j['comment'],
        status: j['status'],
        createdAt: j['createdAt'],
        updatedBy: j['updatedBy'],
      );
}

class SupportTicket {
  final int id;
  final String ticketNumber;
  final String status;
  final String priority;
  final String issueCategory;
  final String issueDescription;
  final String? contactPerson;
  final String? contactPhone;
  final String? contactEmail;
  final bool isChargeable;
  final String? resolution;
  final String? internalNotes;
  final int? clientId;
  final int? assignedOfficerId;
  final int? assignedDeveloperId;
  final Client? client;
  final Employee? assignedOfficer;
  final Employee? assignedDeveloper;
  final List<TicketUpdate> updates;
  final String createdAt;

  SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.priority,
    required this.issueCategory,
    required this.issueDescription,
    this.contactPerson,
    this.contactPhone,
    this.contactEmail,
    required this.isChargeable,
    this.resolution,
    this.internalNotes,
    this.clientId,
    this.assignedOfficerId,
    this.assignedDeveloperId,
    this.client,
    this.assignedOfficer,
    this.assignedDeveloper,
    required this.updates,
    required this.createdAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: j['id'],
        ticketNumber: j['ticketNumber'] ?? '#${j['id']}',
        status: j['status'] ?? 'open',
        priority: j['priority'] ?? 'medium',
        issueCategory: j['issueCategory'] ?? '',
        issueDescription: j['issueDescription'] ?? '',
        contactPerson: j['contactPerson'],
        contactPhone: j['contactPhone'],
        contactEmail: j['contactEmail'],
        isChargeable: j['isChargeable'] ?? false,
        resolution: j['resolution'],
        internalNotes: j['internalNotes'],
        clientId: j['clientId'],
        assignedOfficerId: j['assignedOfficerId'],
        assignedDeveloperId: j['assignedDeveloperId'],
        client: j['client'] != null ? Client.fromJson(j['client']) : null,
        assignedOfficer: j['assignedOfficer'] != null ? Employee.fromJson(j['assignedOfficer']) : null,
        assignedDeveloper: j['assignedDeveloper'] != null ? Employee.fromJson(j['assignedDeveloper']) : null,
        updates: (j['updates'] as List? ?? []).map((u) => TicketUpdate.fromJson(u)).toList(),
        createdAt: j['createdAt'] ?? '',
      );
}
