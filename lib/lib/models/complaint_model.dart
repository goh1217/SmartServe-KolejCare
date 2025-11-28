import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:owtest/models/user_model.dart';

// Complaint model to match Firestore
class Complaint {
  final String id;
  final String title; // from inventoryDamage
  final Student reportedBy; // Changed from studentId to the full Student object
  final String room; // Assuming this comes from student data later
  final String category; // from damageCategory
  final String priority; // from urgencyLevel
  final DateTime submitted; // from reportedDate
  final String status; // from reportStatus

  Complaint({
    required this.id,
    required this.title,
    required this.reportedBy,
    required this.room,
    required this.category,
    required this.priority,
    required this.submitted,
    required this.status,
  });

  // Updated factory to accept a Student object
  factory Complaint.fromFirestore(DocumentSnapshot doc, Student student) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Complaint(
      id: doc.id,
      title: data['inventoryDamage'] ?? 'No Title',
      reportedBy: student, // Use the passed-in student object
      room: 'N/A', // Placeholder, you might need another lookup for this
      category: data['damageCategory'] ?? 'Uncategorized',
      priority: data['urgencyLevel'] ?? 'Low',
      submitted: (data['reportedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['reportStatus'] ?? 'Unknown',
    );
  }
}
//NOTE: The rest of your complaint related models (reports, rating) from the previous version of this file have been removed for clarity based on the immediate request. You may need to add them back in if other parts of your app depend on them.
