import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:owtest/analytics_page.dart';
import 'package:owtest/assign_technician.dart';
import 'package:owtest/help_page.dart';
import 'package:owtest/staff_complaints.dart';

// Main entry widget for the Staff Portal
class StaffPortalApp extends StatelessWidget {
  const StaffPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaffPortalDashboard();
  }
}

// Complaint model
class Complaint {
  final String id;
  final String title;
  final String studentId;
  final String studentName;
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

  static Future<Complaint> fromFirestore(DocumentSnapshot doc) async {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String studentName = 'Unknown Student';
    String studentId = 'Unknown ID';
    String room = 'N/A';

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
  Map<String, dynamic>? _staffData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaffDetails();
  }

  Future<void> _fetchStaffDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();

      if (mounted && querySnapshot.docs.isNotEmpty) {
        setState(() {
          _staffData = querySnapshot.docs.first.data();
        });
      }
    } catch (e) {
      print("Error fetching staff details: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              child: ListView( // Changed to ListView for proper scrolling
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStaffInfoSection(),
                  const SizedBox(height: 24),
                  _buildAnalyticsSection(),
                  const SizedBox(height: 24),
                  _buildRecentActivitySection(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // --- WIDGET BUILDER METHODS ---

  Widget _buildStaffInfoSection() {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
    }

    if (_staffData == null) {
      return const Text('Welcome!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold));
    }

    final staffName = _staffData!['staffName'] ?? 'N/A';
    final staffNo = _staffData!['staffNo'] ?? 'N/A';
    final staffRank = _staffData!['staffRank'] ?? 'N/A';
    final workCollege = _staffData!['workCollege'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, $staffName',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          margin: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInfoRow(Icons.badge_outlined, 'Staff No', staffNo),
                const Divider(height: 24),
                _buildInfoRow(Icons.star_border_outlined, 'Rank', staffRank),
                const Divider(height: 24),
                _buildInfoRow(Icons.school_outlined, 'College', workCollege),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple[400], size: 22),
        const SizedBox(width: 16),
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

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

            final totalComplaints = allDocs.length;
            final completedDocs = allDocs.where((doc) => doc['reportStatus'] == 'Completed').toList();
            final pendingComplaints = allDocs.where((doc) => doc['reportStatus'] == 'Pending').toList();
            final completionRate = totalComplaints > 0 ? (completedDocs.length / totalComplaints) * 100 : 0.0;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildAnalyticsCard(icon: Icons.content_paste, value: totalComplaints.toString(), label: 'Total\nComplaints', color: const Color(0xFF7C3AED), textColor: Colors.black)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAnalyticsCard(icon: Icons.percent, value: '${completionRate.toStringAsFixed(0)}%', label: 'Completion\nRate', color: const Color(0xFF7C3AED), textColor: Colors.black)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAnalyticsCard(icon: Icons.pending_actions, value: pendingComplaints.length.toString(), label: 'Pending\nComplaints', color: const Color(0xFF7C3AED), textColor: Colors.black)),
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

  Widget _buildAnalyticsCard({required IconData icon, required String value, required String label, required Color color, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor ?? color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: color.withOpacity(0.9)), softWrap: true, textAlign: TextAlign.center),
        ],
      ),
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
                
                // Using ListView.builder to render all items correctly inside a scrolling view
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: complaints.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return _buildComplaintCard(complaints[index]);
                  },
                );
              },
            );
          },
        ),
      ],
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
                    text: 'Student: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.studentName),
                const TextSpan(
                    text: ' | Room: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: complaint.room),
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
        return const Color(0xFF7C3AED); // For 'ALL' filter
    }
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

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      selectedItemColor: const Color(0xFF7C3AED),
      unselectedItemColor: Colors.grey[600],
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Complaints'),
        BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'Help'),
      ],
    );
  }
}
