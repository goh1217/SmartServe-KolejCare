import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'assign_technician.dart';

// Re-using the Complaint model from the staff_portal
// If this model is used in more places, consider moving it to its own file in `models/`
class Complaint {
  final String id;
  final String title;
  final String studentId;
  final String studentName; // Added field
  final String room;
  final String category;
  final String priority;
  final DateTime submitted;
  final String status;

  Complaint({
    required this.id,
    required this.title,
    required this.studentId,
    required this.studentName, // Added to constructor
    required this.room,
    required this.category,
    required this.priority,
    required this.submitted,
    required this.status,
  });

  // This is now an async static method to fetch related data
  static Future<Complaint> fromFirestore(DocumentSnapshot doc) async {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String studentName = 'Unknown Student';
    String studentId = 'Unknown ID';
    String room = 'N/A';

    // Handle reportBy being a String path instead of a DocumentReference
    final reportByPath = data['reportBy'] as String?;
    if (reportByPath != null && reportByPath.isNotEmpty) {
      try {
        // Extract the student ID from the path string
        final studentIdFromPath = reportByPath.split('/').last;
        studentId = studentIdFromPath;

        if (studentId.isNotEmpty) {
          // Manually create the DocumentReference to fetch student data
          DocumentReference studentRef = FirebaseFirestore.instance.collection('student').doc(studentId);
          DocumentSnapshot studentDoc = await studentRef.get();

          if (studentDoc.exists) {
            final studentData = studentDoc.data() as Map<String, dynamic>;
            studentName = studentData['studentName'] ?? 'Unnamed Student';

            // Construct room from student's college and block
            final college = studentData['residentCollege'] ?? '';
            final block = studentData['block'] ?? '';
            final tempRoom = '$college $block'.trim();
            if (tempRoom.isNotEmpty) {
              room = tempRoom;
            }
          }
        }
      } catch (e) {
        // Log error for debugging purposes
        print('Error parsing student ref or fetching details for complaint ${doc.id}: $e');
      }
    }

    return Complaint(
      id: doc.id,
      title: data['inventoryDamage'] ?? 'No Title',
      studentId: studentId, // Keep the ID for internal use
      studentName: studentName, // Display this in the UI
      room: room, // Use the constructed room
      category: data['damageCategory'] ?? 'Uncategorized',
      priority: data['urgencyLevel'] ?? 'Low',
      submitted: (data['reportedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['reportStatus'] ?? 'Unknown',
    );
  }
}

class StaffComplaintsPage extends StatefulWidget {
  const StaffComplaintsPage({Key? key}) : super(key: key);

  @override
  _StaffComplaintsPageState createState() => _StaffComplaintsPageState();
}

class _StaffComplaintsPageState extends State<StaffComplaintsPage> {
  String selectedFilter = 'ALL';

  void _navigateToAssignTechnician(Complaint complaint) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignTechnicianPage(
          complaintId: complaint.id,
          complaint: complaint,
        ),
      ),
    );

    // Show success message if technician was assigned
    if (result != null && result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Technician assigned successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The same client-side filtering logic as the dashboard
    Query complaintsQuery = FirebaseFirestore.instance
        .collection('complaint')
        .orderBy('reportedDate', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Complaints', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF7C3AED),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('ALL'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed'),
                ],
              ),
            ),
          ),
          // Complaints List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: complaintsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No complaints found.'));
                }

                // Map docs to a list of Futures
                var complaintFutures = snapshot.data!.docs
                    .map((doc) => Complaint.fromFirestore(doc))
                    .toList();

                // Use a FutureBuilder to wait for all complaint data to be fetched
                return FutureBuilder<List<Complaint>>(
                  future: Future.wait(complaintFutures),
                  builder: (context, complaintSnapshot) {
                    if (complaintSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (complaintSnapshot.hasError) {
                      return Center(
                          child: Text('Error loading details: ${complaintSnapshot.error}'));
                    }
                    if (!complaintSnapshot.hasData || complaintSnapshot.data!.isEmpty) {
                      return const Center(child: Text('No complaints to display.'));
                    }

                    var complaints = complaintSnapshot.data!;

                    if (selectedFilter != 'ALL') {
                      complaints = complaints
                          .where((c) => c.status == selectedFilter)
                          .toList();
                    }

                    if (complaints.isEmpty) {
                      return Center(
                          child: Text('No ${selectedFilter.toLowerCase()} complaints.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: complaints.length,
                      itemBuilder: (context, index) {
                        return _buildComplaintCard(complaints[index]);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            selectedFilter = label;
          });
        }
      },
      backgroundColor: Colors.grey[200],
      selectedColor: _getStatusColor(label).withOpacity(0.2),
      labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? _getStatusColor(label) : Colors.grey[700]),
      shape: StadiumBorder(
          side: isSelected
              ? BorderSide(color: _getStatusColor(label), width: 1.5)
              : BorderSide.none),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    final showAssignButton = complaint.status == 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(complaint.title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: _getStatusColor(complaint.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(complaint.status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(complaint.status))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              children: [
                const TextSpan(
                    text: 'Student: ', // Changed from "Student ID"
                    style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.studentName), // Display student name
                const TextSpan(
                    text: ' | Room: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.room), // Display constructed room
              ],
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              children: [
                const TextSpan(
                    text: 'Category: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.category),
                const TextSpan(
                    text: ' | Priority: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.priority),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
              'Submitted: ${DateFormat.yMMMd().add_jm().format(complaint.submitted)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          
          // Assign Technician Button (only for Pending complaints)
          if (showAssignButton) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToAssignTechnician(complaint),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Assign Technician'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange[700]!;
      case 'In Progress':
        return Colors.blue[700]!;
      case 'Completed':
        return Colors.green[700]!;
      default:
        return const Color(0xFF7C3AED);
    }
  }
}
