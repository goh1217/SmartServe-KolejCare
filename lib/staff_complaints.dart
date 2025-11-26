import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Re-using the Complaint model from the staff_portal
// If this model is used in more places, consider moving it to its own file in `models/`
class Complaint {
  final String id;
  final String title;
  final String studentId;
  final String room;
  final String category;
  final String priority;
  final DateTime submitted;
  final String status;

  Complaint({
    required this.id,
    required this.title,
    required this.studentId,
    required this.room,
    required this.category,
    required this.priority,
    required this.submitted,
    required this.status,
  });

  factory Complaint.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Complaint(
      id: doc.id,
      title: data['inventoryDamage'] ?? 'No Title',
      studentId: (data['reportedBy'] as DocumentReference?)?.id ?? 'Unknown Student',
      room: 'N/A', // Placeholder
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

  @override
  Widget build(BuildContext context) {
    // The same client-side filtering logic as the dashboard
    Query complaintsQuery = FirebaseFirestore.instance.collection('complaint').orderBy('reportedDate', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Complaints'),
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

                var complaints = snapshot.data!.docs.map((doc) => Complaint.fromFirestore(doc)).toList();

                if (selectedFilter != 'ALL') {
                  complaints = complaints.where((c) => c.status == selectedFilter).toList();
                }

                if (complaints.isEmpty) {
                  return Center(child: Text('No ${selectedFilter.toLowerCase()} complaints.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: complaints.length,
                  itemBuilder: (context, index) {
                    return _buildComplaintCard(complaints[index]);
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
      labelStyle: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? _getStatusColor(label) : Colors.grey[700]),
      shape: StadiumBorder(side: isSelected ? BorderSide(color: _getStatusColor(label), width: 1.5) : BorderSide.none),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(complaint.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _getStatusColor(complaint.status).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(complaint.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(complaint.status))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              children: [
                const TextSpan(text: 'Student ID: ', style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.studentId),
                const TextSpan(text: ' | Room: ', style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.room),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              children: [
                const TextSpan(text: 'Category: ', style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.category),
                const TextSpan(text: ' | Priority: ', style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.priority),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Submitted: ${DateFormat.yMMMd().add_jm().format(complaint.submitted)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
