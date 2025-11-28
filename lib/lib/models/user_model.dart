/// Base User class
abstract class User {
  final String uid;
  final String email;
  final String name;
  final String phoneNo;

  User({
    required this.uid,
    required this.email,
    required this.name,
    required this.phoneNo,
  });
}

/// Student class inheriting from User
class Student extends User {
  final String matricNo;
  final String residentCollege;
  final int year;
  // Lists for relationships (can be IDs or actual objects)
  final List<String> currentComplaint;
  final List<String> complaintHistory;
  final List<String> donationHistory;

  Student({
    required super.uid,
    required super.email,
    required String studentName,
    required super.phoneNo,
    required this.matricNo,
    required this.residentCollege,
    required this.year,
    this.currentComplaint = const [],
    this.complaintHistory = const [],
    this.donationHistory = const [],
  }) : super(name: studentName);
}

/// Staff class inheriting from User
class Staff extends User {
  final String staffNo;
  final String staffRank;
  final String workCollege;

  Staff({
    required super.uid,
    required super.email,
    required String staffName,
    required super.phoneNo,
    required this.staffNo,
    required this.staffRank,
    required this.workCollege,
  }) : super(name: staffName);
}

/// Technician class inheriting from User
class Technician extends User {
  final String technicianNo;
  final String maintenanceField;
  final bool availability;
  final double monthlySalary;
  // List for relationship
  final List<String> tasksAssigned;

  Technician({
    required super.uid,
    required super.email,
    required String technicianName,
    required super.phoneNo,
    required this.technicianNo,
    required this.maintenanceField,
    required this.availability,
    required this.monthlySalary,
    this.tasksAssigned = const [],
  }) : super(name: technicianName);
}
