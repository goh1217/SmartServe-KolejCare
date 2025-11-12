import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:owtest/analytics_page.dart';
import 'package:owtest/help_page.dart';
import 'package:owtest/staff_complaints.dart';

class StaffPortalApp extends StatelessWidget {
  const StaffPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StaffPortalHome();
  }
}

class StaffPortalHome extends StatefulWidget {
  const StaffPortalHome({Key? key}) : super(key: key);

  @override
  State<StaffPortalHome> createState() => _StaffPortalHomeState();
}

class _StaffPortalHomeState extends State<StaffPortalHome> {
  int _selectedIndex = 0;

  final List<Complaint> complaints = [
    Complaint(
      id: 1,
      title: 'Broken Light Switch',
      status: ComplaintStatus.pending,
      student: 'Ow Yee Hao',
      room: '315',
      category: 'electrical',
      priority: 'medium',
      submitted: '15 Jan 2025, 10:30 AM',
    ),
    Complaint(
      id: 2,
      title: 'Leaky Faucet',
      status: ComplaintStatus.inProgress,
      student: 'Chong LunLun',
      room: '355',
      category: 'plumbing',
      priority: 'high',
      submitted: '10 Sep 2025, 7:30 AM',
    ),
    Complaint(
      id: 3,
      title: 'Damaged Desk',
      status: ComplaintStatus.completed,
      student: 'Chew Jie He',
      room: '100',
      category: 'furniture',
      priority: 'low',
      submitted: '9 Mar 2025, 8:05 PM',
    ),
  ];

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StaffComplaintsPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AnalyticsPage()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HelpPage()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        leading: const Icon(Icons.menu, color: Colors.white),
        title: Row(
          children: const [
            Icon(Icons.build, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Staff Portal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Analytics Title
              const Text(
                'System Analytics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Analytics Cards
              Row(
                children: [
                  Expanded(
                    child: _buildAnalyticsCard(
                      icon: Icons.assignment,
                      value: '32',
                      label: 'Total\nComplaints',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAnalyticsCard(
                      icon: Icons.percent,
                      value: '50%',
                      label: 'Completion\nRate',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAnalyticsCard(
                      icon: Icons.access_time,
                      value: '1.3h',
                      label: 'Avg.\nResolution\nTime',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // View All Complaints Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StaffComplaintsPage()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.list, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'View All Complaints',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recent Activity Title
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              // Complaints List with Scrollbar
              SizedBox(
                height: 350,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    itemCount: complaints.length,
                    itemBuilder: (context, index) => _buildComplaintCard(complaints[index]),
                  ),
                ),
              ),
              const SizedBox(height: 80), // Padding for bottom nav
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Complaints',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: 'Help',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF7C3AED),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  Widget _buildAnalyticsCard({required IconData icon, required String value, required String label}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF6D28D9)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  complaint.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              _buildStatusBadge(complaint.status),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              children: [
                const TextSpan(
                  text: 'Student: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: complaint.student),
                const TextSpan(
                  text: ' | Room: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: complaint.room),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              children: [
                const TextSpan(
                  text: 'Category: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: complaint.category),
                const TextSpan(
                  text: ' | Priority: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: complaint.priority),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submitted: ${complaint.submitted}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ComplaintStatus status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case ComplaintStatus.pending:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        text = 'PENDING';
        break;
      case ComplaintStatus.inProgress:
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1E40AF);
        text = 'IN PROGRESS';
        break;
      case ComplaintStatus.completed:
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        text = 'COMPLETED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Models
enum ComplaintStatus { pending, inProgress, completed }

class Complaint {
  final int id;
  final String title;
  final ComplaintStatus status;
  final String student;
  final String room;
  final String category;
  final String priority;
  final String submitted;

  Complaint({
    required this.id,
    required this.title,
    required this.status,
    required this.student,
    required this.room,
    required this.category,
    required this.priority,
    required this.submitted,
  });
}
