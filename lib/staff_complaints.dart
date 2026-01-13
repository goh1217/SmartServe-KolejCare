import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'assign_technician.dart';
import 'complaint_details.dart';

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
  final String residentCollege; // Added for filtering
  final String? reasonCantComplete;
  final String? reasonCantCompleteProof;
  final int cantCompleteCount;
  final DateTime? suggestedDate; // For rescheduling

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
    required this.residentCollege,
    required this.reasonCantComplete,
    required this.reasonCantCompleteProof,
    required this.cantCompleteCount,
    this.suggestedDate,
  });

  // This is now an async static method to fetch related data
  static Future<Complaint> fromFirestore(DocumentSnapshot doc) async {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String studentName = 'Unknown Student';
    String studentId = 'Unknown ID';
    String room = 'N/A';
    String residentCollege = '';

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

            // Format room as: roomNumber,block
            final roomNumber = studentData['roomNumber']?.toString() ?? '';
            final block = studentData['block']?.toString() ?? '';
            
            final List<String> roomParts = [];
            if (roomNumber.isNotEmpty) roomParts.add(roomNumber);
            if (block.isNotEmpty) roomParts.add(block);
            
            if (roomParts.isNotEmpty) {
              room = roomParts.join(',');
            }
            
            // Get residentCollege for filtering
            residentCollege = studentData['residentCollege']?.toString() ?? '';
          }
        }
      } catch (e) {
        // Log error for debugging purposes
        print('Error parsing student ref or fetching details for complaint ${doc.id}: $e');
      }
    }

    return Complaint(
      id: doc.id,
      title: data['inventoryDamageTitle'] ?? 'No Title',
      studentId: studentId, // Keep the ID for internal use
      studentName: studentName, // Display this in the UI
      room: room, // Use the constructed room
      category: data['damageCategory'] ?? 'Uncategorized',
      priority: data['urgencyLevel'] ?? 'Low',
      submitted: (data['reportedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['reportStatus'] ?? 'Unknown',
      residentCollege: residentCollege,
      reasonCantComplete: data['reasonCantComplete'] is List
          ? (data['reasonCantComplete'] as List).isNotEmpty
              ? (data['reasonCantComplete'] as List).first?.toString()
              : null
          : data['reasonCantComplete']?.toString(),
      reasonCantCompleteProof: () {
        final raw = data['reasonCantCompleteProof'];
        if (raw == null) return null;
        if (raw is List) {
          if (raw.isEmpty) return null;
          return raw.first?.toString();
        }
        return raw.toString();
      }(),
      cantCompleteCount: (data['cantCompleteCount'] is int)
          ? data['cantCompleteCount'] as int
          : int.tryParse((data['cantCompleteCount'] ?? '').toString()) ?? 0,
      suggestedDate: (data['suggestedDate'] as Timestamp?)?.toDate(),
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
  String selectedSort = 'Priority (High to Low)';
  String? _staffWorkCollege;
  bool _isLoadingStaff = true;

  @override
  void initState() {
    super.initState();
    _fetchStaffWorkCollege();
  }

  Future<void> _fetchStaffWorkCollege() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        if (mounted) setState(() => _isLoadingStaff = false);
        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();

      if (mounted && querySnapshot.docs.isNotEmpty) {
        final staffData = querySnapshot.docs.first.data();
        setState(() {
          _staffWorkCollege = staffData['workCollege']?.toString();
          _isLoadingStaff = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingStaff = false);
      }
    } catch (e) {
      print("Error fetching staff workCollege: $e");
      if (mounted) setState(() => _isLoadingStaff = false);
    }
  }

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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter Chips and Sort Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('ALL'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Ongoing'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rejected'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Cancelled'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('Sort by: ',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedSort,
                          isExpanded: true,
                          underline: Container(
                            height: 1,
                            color: Colors.grey[300],
                          ),
                          items: [
                            'Priority (High to Low)',
                            'Priority (Low to High)',
                            'Date (Oldest First)',
                            'Date (Newest First)',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value,
                                  style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedSort = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

                    // Filter by staff's workCollege
                    if (_staffWorkCollege != null && _staffWorkCollege!.isNotEmpty) {
                      complaints = complaints
                          .where((c) => c.residentCollege == _staffWorkCollege)
                          .toList();
                    }

                    // Filter by status
                    if (selectedFilter != 'ALL') {
                      complaints = complaints
                          .where((c) => c.status == selectedFilter)
                          .toList();
                    }

                    // Sort based on selected sort mode
                    complaints.sort((a, b) {
                      switch (selectedSort) {
                        case 'Priority (High to Low)':
                          final priorityCompare = _getPriorityOrder(a.priority).compareTo(_getPriorityOrder(b.priority));
                          if (priorityCompare != 0) return priorityCompare;
                          return a.submitted.compareTo(b.submitted);
                        case 'Priority (Low to High)':
                          final priorityCompare = _getPriorityOrder(b.priority).compareTo(_getPriorityOrder(a.priority));
                          if (priorityCompare != 0) return priorityCompare;
                          return a.submitted.compareTo(b.submitted);
                        case 'Date (Oldest First)':
                          return a.submitted.compareTo(b.submitted);
                        case 'Date (Newest First)':
                          return b.submitted.compareTo(a.submitted);
                        default:
                          return 0;
                      }
                    });

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
    final bool hasCantCompleteInfo = (complaint.reasonCantComplete != null && complaint.reasonCantComplete!.isNotEmpty) ||
        (complaint.reasonCantCompleteProof != null && complaint.reasonCantCompleteProof!.isNotEmpty) ||
        complaint.cantCompleteCount > 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComplaintDetailsPage(complaint: complaint),
          ),
        );
      },
      child: Container(
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
              // Previously attempted tag
              if (complaint.status == 'Pending' && hasCantCompleteInfo) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text(
                        'Previously attempted${complaint.cantCompleteCount > 0 ? ' (${complaint.cantCompleteCount})' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
              // Rescheduled tag
              if (complaint.suggestedDate != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        'Rescheduled',
                        style: TextStyle(fontSize: 12, color: Colors.amber[800], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
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
                TextSpan(
                    text: complaint.priority,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _getPriorityColor(complaint.priority))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
              'Submitted: ${DateFormat.yMMMd().add_jm().format(complaint.submitted)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          
          // Assign Technician Button (only for Pending complaints)
          if (showAssignButton) ...[
            // (previous attempt details removed per request)
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
      ),
    );
  }

  int _getPriorityOrder(String priority) {
    switch (priority) {
      case 'High':
        return 0;
      case 'Medium':
        return 1;
      case 'Low':
        return 2;
      default:
        return 3;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red[700]!;
      case 'Medium':
        return Colors.orange[700]!;
      case 'Low':
        return Colors.green[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.yellow[700]!;
      case 'Approved':
        return Colors.purple[700]!;
      case 'Ongoing':
        return Colors.blue[700]!;
      case 'Completed':
        return Colors.green[700]!;
      case 'Rejected':
        return Colors.red[700]!;
      case 'Cancelled':
        return Colors.grey[700]!;
      default:
        return const Color(0xFF7C3AED);
    }
  }
}
