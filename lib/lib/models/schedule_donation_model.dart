import 'package:owtest/models/complaint_model.dart';
import 'package:owtest/models/user_model.dart';

/// Represents a Donation
class Donation {
  final String donationId;
  final double amount;
  final DateTime date;
  final Student? donatedBy;
  final Technician? receivedBy;

  Donation({
    required this.donationId,
    required this.amount,
    required this.date,
    this.donatedBy,
    this.receivedBy,
  });
}

/// Represents a work schedule for a technician
class Schedule {
  final String scheduleId;
  final DateTime startTime;
  final DateTime endTime;
  final Technician technician;
  final List<Complaint> complaints;

  Schedule({
    required this.scheduleId,
    required this.startTime,
    required this.endTime,
    required this.technician,
    this.complaints = const [],
  });
}

/// Manages multiple schedules for a college
class CollegeSchedule {
  final String collegeScheduleId;
  final String collegeName;
  final List<Schedule> schedules;

  CollegeSchedule({
    required this.collegeScheduleId,
    required this.collegeName,
    this.schedules = const [],
  });
}
