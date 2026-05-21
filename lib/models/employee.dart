class Department {
  final int id;
  final String name;
  final String code;

  Department({required this.id, required this.name, required this.code});

  factory Department.fromJson(Map<String, dynamic> j) =>
      Department(id: j['id'], name: j['name'] ?? '', code: j['code'] ?? '');
}

class Employee {
  final int id;
  final String employeeNumber;
  final String firstName;
  final String lastName;
  final String jobTitle;
  final String? email;
  final String? phone;
  final String dateJoined;
  final String status;
  final String? photo;
  final String? notes;
  final int? departmentId;
  final int? supervisorId;
  final Department? department;
  final Employee? supervisor;

  Employee({
    required this.id,
    required this.employeeNumber,
    required this.firstName,
    required this.lastName,
    required this.jobTitle,
    this.email,
    this.phone,
    required this.dateJoined,
    required this.status,
    this.photo,
    this.notes,
    this.departmentId,
    this.supervisorId,
    this.department,
    this.supervisor,
  });

  String get fullName => '$firstName $lastName';

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'],
        employeeNumber: j['employeeNumber'] ?? '',
        firstName: j['firstName'] ?? '',
        lastName: j['lastName'] ?? '',
        jobTitle: j['jobTitle'] ?? '',
        email: j['email'],
        phone: j['phone'],
        dateJoined: j['dateJoined'] ?? '',
        status: j['status'] ?? 'active',
        photo: j['photo'],
        notes: j['notes'],
        departmentId: j['departmentId'],
        supervisorId: j['supervisorId'],
        department: j['department'] != null ? Department.fromJson(j['department']) : null,
        supervisor: j['supervisor'] != null ? Employee.fromJson(j['supervisor']) : null,
      );
}
