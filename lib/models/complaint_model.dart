import 'package:owtest/models/user_model.dart';

/// Represents the main Complaint entity
class Complaint {
  final String complaintId;
  final Student reportedBy;
  final DateTime reportedDate;
  final String description;
  final String category;

  // For relationships
  Staff? reviewedBy;
  Technician? assignedTo;
  Rating? feedbackRating;
  ComplaintReport? status;

  Complaint({
    required this.complaintId,
    required this.reportedBy,
    required this.reportedDate,
    required this.description,
    required this.category,
    this.reviewedBy,
    this.assignedTo,
    this.feedbackRating,
    this.status,
  });
}

/// Base class for the different states of a complaint report
abstract class ComplaintReport {
  final String reportId;
  final DateTime timestamp;

  ComplaintReport({required this.reportId, required this.timestamp});
}

// Specific report states inheriting from ComplaintReport
class OngoingReport extends ComplaintReport {
  OngoingReport({required super.reportId, required super.timestamp});
}

class RejectedReport extends ComplaintReport {
  final String reason;
  RejectedReport({required super.reportId, required super.timestamp, required this.reason});
}

class ScheduledReport extends ComplaintReport {
  final DateTime scheduledDate;
  ScheduledReport({required super.reportId, required super.timestamp, required this.scheduledDate});
}

class CompletedReport extends ComplaintReport {
  final String summary;
  CompletedReport({required super.reportId, required super.timestamp, required this.summary});
}

class WaitingApprovalReport extends ComplaintReport {
  WaitingApprovalReport({required super.reportId, required super.timestamp});
}

/// Represents a Rating
class Rating {
  final String ratingId;
  final int score; // e.g., 1-5
  final String comment;
  final Student givenBy;
  final Technician ratedTechnician;

  Rating({
    required this.ratingId,
    required this.score,
    required this.comment,
    required this.givenBy,
    required this.ratedTechnician,
  });
}
