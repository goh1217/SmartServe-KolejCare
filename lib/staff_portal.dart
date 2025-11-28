import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:owtest/analytics_page.dart';
import 'package:owtest/help_page.dart';
import 'package:owtest/staff_complaints.dart';

// Main entry widget for the Staff Portal, used by AuthGate
class StaffPortalApp extends StatelessWidget {
  const StaffPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaffPortalDashboard();
  }
}

// Updated Complaint model to fetch student details asynchronously
class Complaint {
  final String id;
  final String title;
  final String studentId;
  final String studentName; // Added for displaying name
  final String room;
  final String category;
  final String priority;
  final DateTime submitted;
  final String status;

  Complaint({
    required this.id,
    required this.title,
    required this.studentId,
    required this.studentName,
    required this.room,
    required this.category,
    required this.priority,
    required this.submitted,
    required this.status,
  });

  // Factory constructor to create a Complaint from a Firestore document
  static Future<Complaint> fromFirestore(DocumentSnapshot doc) async {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String studentName = 'Unknown Student';
    String studentId = 'Unknown ID';
    String room = 'N/A';

    // Handle reportBy being a String path instead of a DocumentReference
    final reportByPath = data['reportBy'] as String?;
    if (reportByPath != null && reportByPath.isNotEmpty) {
      try {
        final studentIdFromPath = reportByPath.split('/').last;
        studentId = studentIdFromPath;

        if (studentId.isNotEmpty) {
          DocumentReference studentRef = FirebaseFirestore.instance.collection('student').doc(studentId);
          DocumentSnapshot studentDoc = await studentRef.get();

          if (studentDoc.exists) {
            final studentData = studentDoc.data() as Map<String, dynamic>;
            studentName = studentData['studentName'] ?? 'Unnamed Student';

            final college = studentData['residentCollege'] ?? '';
            final block = studentData['block'] ?? '';
            final tempRoom = '$college $block'.trim();
            if (tempRoom.isNotEmpty) {
              room = tempRoom;
            }
          }
        }
      } catch (e) {
        print('Error parsing student ref or fetching details for complaint ${doc.id}: $e');
      }
    }

    return Complaint(
      id: doc.id,
      title: data['inventoryDamage'] ?? 'No Title',
      studentId: studentId,
      studentName: studentName,
      room: room,
      category: data['damageCategory'] ?? 'Uncategorized',
      priority: data['urgencyLevel'] ?? 'Low',
      submitted: (data['reportedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['reportStatus'] ?? 'Unknown',
    );
  }
}

class StaffPortalDashboard extends StatefulWidget {
  const StaffPortalDashboard({Key? key}) : super(key: key);

  @override
  State<StaffPortalDashboard> createState() => _StaffPortalDashboardState();
}

class _StaffPortalDashboardState extends State<StaffPortalDashboard> {
  int _selectedIndex = 0;
  String selectedFilter = 'ALL';

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffComplaintsPage()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsPage()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpPage()));
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAnalyticsSection(),
                      const SizedBox(height: 24),
                      _buildRecentActivitySection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // --- WIDGET BUILDER METHODS ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu, color: Colors.white),
          const SizedBox(width: 12),
          const Icon(Icons.build, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          const Text('Staff Portal', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('System Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('complaint').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading analytics'));
            }

            final allDocs = snapshot.data!.docs;
            
            // 1. Calculate Total Complaints
            final totalComplaints = allDocs.length;

            // 2. Calculate Completion Rate
            final completedDocs = allDocs.where((doc) => doc['reportStatus'] == 'Completed').toList();
            final completionRate = totalComplaints > 0 ? (completedDocs.length / totalComplaints) * 100 : 0.0;

            // 3. Calculate Average Resolution Time
            double totalResolutionHours = 0;
            int resolvedWithDatesCount = 0;
            for (var doc in completedDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final reportedDate = (data['reportedDate'] as Timestamp?)?.toDate();
              final scheduleDate = (data['scheduleDate'] as Timestamp?)?.toDate(); // Using scheduleDate as resolution date

              if (reportedDate != null && scheduleDate != null) {
                totalResolutionHours += scheduleDate.difference(reportedDate).inHours;
                resolvedWithDatesCount++;
              }
            }
            final avgHours = resolvedWithDatesCount > 0 ? totalResolutionHours / resolvedWithDatesCount : 0.0;

            return IntrinsicHeight( // Ensures all cards have the same height
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildAnalyticsCard(icon: Icons.content_paste, value: totalComplaints.toString(), label: 'Total\nComplaints', color: const Color(0xFF7C3AED))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAnalyticsCard(icon: Icons.percent, value: '${completionRate.toStringAsFixed(0)}%', label: 'Completion\nRate', color: const Color(0xFF7C3AED))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAnalyticsCard(icon: Icons.access_time, value: '${avgHours.toStringAsFixed(1)}h', label: 'Avg.\nResolution\nTime', color: const Color(0xFF7C3AED))),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffComplaintsPage())),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            icon: const Icon(Icons.list, color: Colors.white),
            label: const Text('View All Complaints', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    Query complaintsQuery = FirebaseFirestore.instance.collection('complaint').orderBy('reportedDate', descending: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: complaintsQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No complaints found', style: TextStyle(fontSize: 16, color: Colors.grey))));
            }

            var complaintFutures = snapshot.data!.docs.map((doc) => Complaint.fromFirestore(doc)).toList();

            return FutureBuilder<List<Complaint>>(
              future: Future.wait(complaintFutures),
              builder: (context, complaintSnapshot) {
                 if (complaintSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (complaintSnapshot.hasError) {
                  return Center(child: Text('Error loading details: ${complaintSnapshot.error}'));
                }
                if (!complaintSnapshot.hasData || complaintSnapshot.data!.isEmpty) {
                  return const Center(child: Text('No complaints to display.'));
                }

                var complaints = complaintSnapshot.data!;

                if (selectedFilter != 'ALL') {
                  complaints = complaints.where((c) => c.status == selectedFilter).toList();
                }

                if (complaints.isEmpty) {
                  return Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('No ${selectedFilter.toLowerCase()} complaints', style: TextStyle(fontSize: 16, color: Colors.grey[600]))));
                }

                return Column(
                  children: complaints.take(5).map((complaint) => _buildComplaintCard(complaint)).toList(), // Show top 5
                );
              },
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildAnalyticsCard({required IconData icon, required String value, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.2)),
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
                const TextSpan(text: 'Student: ', style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.studentName), // Use student name
                const TextSpan(text: ' | Room: ', style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.room), // Use fetched room
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

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF7C3AED),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.content_paste), label: 'Complaints'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'Help'),
      ],
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
