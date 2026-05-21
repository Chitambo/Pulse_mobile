import 'employee.dart';
import 'client.dart';

class DailyActivity {
  final int id;
  final String date;
  final String activityType;
  final String description;
  final String? startTime;
  final String? endTime;
  final String status;
  final String revenueImpact;
  final String? supervisorRemarks;
  final int? employeeId;
  final int? clientId;
  final int? projectId;
  final Employee? employee;
  final Client? client;
  final String createdAt;

  DailyActivity({
    required this.id,
    required this.date,
    required this.activityType,
    required this.description,
    this.startTime,
    this.endTime,
    required this.status,
    required this.revenueImpact,
    this.supervisorRemarks,
    this.employeeId,
    this.clientId,
    this.projectId,
    this.employee,
    this.client,
    required this.createdAt,
  });

  factory DailyActivity.fromJson(Map<String, dynamic> j) => DailyActivity(
        id: j['id'],
        date: j['date'] ?? '',
        activityType: j['activityType'] ?? 'other',
        description: j['description'] ?? '',
        startTime: j['startTime'],
        endTime: j['endTime'],
        status: j['status'] ?? 'completed',
        revenueImpact: j['revenueImpact'] ?? 'none',
        supervisorRemarks: j['supervisorRemarks'],
        employeeId: j['employeeId'],
        clientId: j['clientId'],
        projectId: j['projectId'],
        employee: j['employee'] != null ? Employee.fromJson(j['employee']) : null,
        client: j['client'] != null ? Client.fromJson(j['client']) : null,
        createdAt: j['createdAt'] ?? '',
      );
}
