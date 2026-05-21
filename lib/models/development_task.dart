import 'employee.dart';

class DevelopmentTask {
  final int id;
  final String title;
  final String description;
  final String taskType;
  final String status;
  final String priority;
  final String? dueDate;
  final int? percentageProgress;
  final String? module;
  final String? gitBranch;
  final String? gitCommit;
  final String? testingNotes;
  final String? deploymentNotes;
  final String? delayReason;
  final int? projectId;
  final int? assignedDeveloperId;
  final int? relatedTicketId;
  final int? clientId;
  final Employee? assignedDeveloper;
  final String createdAt;

  DevelopmentTask({
    required this.id,
    required this.title,
    required this.description,
    required this.taskType,
    required this.status,
    required this.priority,
    this.dueDate,
    this.percentageProgress,
    this.module,
    this.gitBranch,
    this.gitCommit,
    this.testingNotes,
    this.deploymentNotes,
    this.delayReason,
    this.projectId,
    this.assignedDeveloperId,
    this.relatedTicketId,
    this.clientId,
    this.assignedDeveloper,
    required this.createdAt,
  });

  factory DevelopmentTask.fromJson(Map<String, dynamic> j) => DevelopmentTask(
        id: j['id'],
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        taskType: j['taskType'] ?? 'feature',
        status: j['status'] ?? 'pending',
        priority: j['priority'] ?? 'medium',
        dueDate: j['dueDate'],
        percentageProgress: j['percentageProgress'],
        module: j['module'],
        gitBranch: j['gitBranch'],
        gitCommit: j['gitCommit'],
        testingNotes: j['testingNotes'],
        deploymentNotes: j['deploymentNotes'],
        delayReason: j['delayReason'],
        projectId: j['projectId'],
        assignedDeveloperId: j['assignedDeveloperId'],
        relatedTicketId: j['relatedTicketId'],
        clientId: j['clientId'],
        assignedDeveloper: j['assignedDeveloper'] != null
            ? Employee.fromJson(j['assignedDeveloper'])
            : null,
        createdAt: j['createdAt'] ?? '',
      );
}
