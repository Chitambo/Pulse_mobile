class WeeklySummary {
  final int id;
  final String weekEnding;
  final String? completedTasks;
  final String? pendingTasks;
  final String? delayedTasks;
  final double? revenueContributed;
  final String? clientIssues;
  final String? internalIssues;
  final String? targetsNextWeek;
  final String? supervisorComments;
  final int? employeeId;
  final String createdAt;

  WeeklySummary({
    required this.id,
    required this.weekEnding,
    this.completedTasks,
    this.pendingTasks,
    this.delayedTasks,
    this.revenueContributed,
    this.clientIssues,
    this.internalIssues,
    this.targetsNextWeek,
    this.supervisorComments,
    this.employeeId,
    required this.createdAt,
  });

  factory WeeklySummary.fromJson(Map<String, dynamic> j) => WeeklySummary(
        id: j['id'],
        weekEnding: j['weekEnding'] ?? '',
        completedTasks: j['completedTasks'],
        pendingTasks: j['pendingTasks'],
        delayedTasks: j['delayedTasks'],
        revenueContributed: j['revenueContributed'] != null
            ? double.tryParse(j['revenueContributed'].toString())
            : null,
        clientIssues: j['clientIssues'],
        internalIssues: j['internalIssues'],
        targetsNextWeek: j['targetsNextWeek'],
        supervisorComments: j['supervisorComments'],
        employeeId: j['employeeId'],
        createdAt: j['createdAt'] ?? '',
      );
}
