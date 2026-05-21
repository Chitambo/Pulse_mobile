import 'employee.dart';

class KpiTemplate {
  final int id;
  final String name;
  final String? description;
  final int? departmentId;
  final String? roleSlug;
  final String? measurementMethod;
  final double? target;
  final double? weight;
  final String? frequency;
  final bool evidenceRequired;
  final Department? department;

  KpiTemplate({
    required this.id,
    required this.name,
    this.description,
    this.departmentId,
    this.roleSlug,
    this.measurementMethod,
    this.target,
    this.weight,
    this.frequency,
    required this.evidenceRequired,
    this.department,
  });

  factory KpiTemplate.fromJson(Map<String, dynamic> j) => KpiTemplate(
        id: j['id'],
        name: j['name'] ?? '',
        description: j['description'],
        departmentId: j['departmentId'],
        roleSlug: j['roleSlug'],
        measurementMethod: j['measurementMethod'],
        target: j['target'] != null ? double.tryParse(j['target'].toString()) : null,
        weight: j['weight'] != null ? double.tryParse(j['weight'].toString()) : null,
        frequency: j['frequency'],
        evidenceRequired: j['evidenceRequired'] ?? false,
        department: j['department'] != null ? Department.fromJson(j['department']) : null,
      );
}

class KpiScore {
  final int id;
  final int employeeId;
  final int kpiTemplateId;
  final int month;
  final int year;
  final double? target;
  final double? actualPerformance;
  final double? score;
  final double? weight;
  final String? supervisorComments;
  final double? ceoAdjustedScore;
  final String? ceoComments;
  final String? status;
  final KpiTemplate? template;
  final Employee? employee;

  KpiScore({
    required this.id,
    required this.employeeId,
    required this.kpiTemplateId,
    required this.month,
    required this.year,
    this.target,
    this.actualPerformance,
    this.score,
    this.weight,
    this.supervisorComments,
    this.ceoAdjustedScore,
    this.ceoComments,
    this.status,
    this.template,
    this.employee,
  });

  factory KpiScore.fromJson(Map<String, dynamic> j) => KpiScore(
        id: j['id'],
        employeeId: j['employeeId'],
        kpiTemplateId: j['kpiTemplateId'],
        month: j['month'],
        year: j['year'],
        target: j['target'] != null ? double.tryParse(j['target'].toString()) : null,
        actualPerformance: j['actualPerformance'] != null
            ? double.tryParse(j['actualPerformance'].toString())
            : null,
        score: j['score'] != null ? double.tryParse(j['score'].toString()) : null,
        weight: j['weight'] != null ? double.tryParse(j['weight'].toString()) : null,
        supervisorComments: j['supervisorComments'],
        ceoAdjustedScore: j['ceoAdjustedScore'] != null
            ? double.tryParse(j['ceoAdjustedScore'].toString())
            : null,
        ceoComments: j['ceoComments'],
        status: j['status'],
        template: j['kpiTemplate'] != null ? KpiTemplate.fromJson(j['kpiTemplate']) : null,
        employee: j['employee'] != null ? Employee.fromJson(j['employee']) : null,
      );
}

class KpiScorecardSummary {
  final int totalKPIs;
  final double overallScore;
  final String rating;

  KpiScorecardSummary({
    required this.totalKPIs,
    required this.overallScore,
    required this.rating,
  });

  factory KpiScorecardSummary.fromJson(Map<String, dynamic> j) => KpiScorecardSummary(
        totalKPIs: j['totalKPIs'] ?? 0,
        overallScore: double.tryParse(j['overallScore']?.toString() ?? '0') ?? 0,
        rating: j['rating'] ?? 'needs_improvement',
      );
}
