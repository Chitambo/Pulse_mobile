class ApprovalStep {
  final int id;
  final int sequence;
  final String requiredRole;
  final String status; // pending | approved | rejected | skipped
  final String? comment;
  final String? actedAt;

  ApprovalStep({
    required this.id,
    required this.sequence,
    required this.requiredRole,
    required this.status,
    this.comment,
    this.actedAt,
  });

  factory ApprovalStep.fromJson(Map<String, dynamic> j) => ApprovalStep(
        id: j['id'],
        sequence: j['sequence'] ?? 0,
        requiredRole: j['requiredRole'] ?? '',
        status: j['status'] ?? 'pending',
        comment: j['comment'],
        actedAt: j['actedAt'],
      );
}

class ApprovalRequest {
  final int id;
  final String entityType;
  final int entityId;
  final double? amount;
  final String status; // pending | approved | rejected | cancelled
  final int requestedById;
  final int currentStep;
  final List<ApprovalStep> steps;
  final Map<String, dynamic>? entity; // lightweight summary from the API
  final String? requestedByName;

  ApprovalRequest({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.amount,
    required this.status,
    required this.requestedById,
    required this.currentStep,
    required this.steps,
    this.entity,
    this.requestedByName,
  });

  ApprovalStep? get current {
    for (final s in steps) {
      if (s.sequence == currentStep) return s;
    }
    return null;
  }

  String get title {
    if (entityType == 'expense' && entity != null) {
      final num = entity!['expenseNumber'] ?? 'EXP';
      final payee = entity!['payee'] ?? '';
      return '$num · $payee';
    }
    return '$entityType #$entityId';
  }

  static String? _name(Map<String, dynamic>? rb) {
    if (rb == null) return null;
    final emp = rb['employee'];
    if (emp != null) return '${emp['firstName']} ${emp['lastName']}';
    return rb['username'];
  }

  factory ApprovalRequest.fromJson(Map<String, dynamic> j) => ApprovalRequest(
        id: j['id'],
        entityType: j['entityType'] ?? '',
        entityId: j['entityId'] ?? 0,
        amount: j['amount'] == null ? null : double.tryParse(j['amount'].toString()),
        status: j['status'] ?? 'pending',
        requestedById: j['requestedById'] ?? 0,
        currentStep: j['currentStep'] ?? 1,
        steps: (j['steps'] as List? ?? [])
            .map((s) => ApprovalStep.fromJson(s as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence)),
        entity: j['entity'] as Map<String, dynamic>?,
        requestedByName: _name(j['requestedBy'] as Map<String, dynamic>?),
      );
}
