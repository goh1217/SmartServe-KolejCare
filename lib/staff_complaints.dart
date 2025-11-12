import 'package:flutter/material.dart';
import 'package:owtest/analytics_page.dart';
import 'package:owtest/assign_technician.dart';
import 'package:owtest/complaint_details.dart';
import 'package:owtest/help_page.dart';

class StaffComplaintsPage extends StatefulWidget {
  const StaffComplaintsPage({Key? key}) : super(key: key);

  @override
  _StaffComplaintsPageState createState() => _StaffComplaintsPageState();
}

class _StaffComplaintsPageState extends State<StaffComplaintsPage> {
  int _selectedIndex = 1; // Set to 1 for Complaints tab
  String _selectedFilter = 'All';

  final List<Complaint> complaints = [
    Complaint(
        id: 1,
        title: 'Broken Light Switch',
        status: ComplaintStatus.pending,
        student: 'Ow Yee Hao',
        room: '315',
        category: 'electrical',
        priority: 'medium',
        submitted: '15 Jan 2025, 10:30 AM'),
    Complaint(
        id: 2,
        title: 'Leaky Faucet',
        status: ComplaintStatus.inProgress,
        student: 'Chong LunLun',
        room: '355',
        category: 'plumbing',
        priority: 'high',
        submitted: '10 Sep 2025, 7:30 AM'),
    Complaint(
        id: 3,
        title: 'Damaged Desk',
        status: ComplaintStatus.completed,
        student: 'Chew Jie He',
        room: '100',
        category: 'furniture',
        priority: 'low',
        submitted: '9 Mar 2025, 8:05 PM'),
    Complaint(
        id: 4,
        title: 'Broken Light Switch',
        status: ComplaintStatus.pending,
        student: 'Ong Jun Hao',
        room: '456',
        category: 'electrical',
        priority: 'medium',
        submitted: '12 Jan 2025, 2:15 PM'),
  ];

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    final filteredComplaints = complaints.where((c) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Pending') return c.status == ComplaintStatus.pending;
      if (_selectedFilter == 'In Progress') return c.status == ComplaintStatus.inProgress;
      if (_selectedFilter == 'Completed') return c.status == ComplaintStatus.completed;
      return false;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        backgroundColor: const Color(0xFF6D28D9),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout), // Using a logout icon as a placeholder
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: filteredComplaints.length,
              itemBuilder: (context, index) {
                return _buildComplaintCard(filteredComplaints[index]);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Complaints'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.help), label: 'Help'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF7C3AED),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ['All', 'Pending', 'In Progress', 'Completed'].map((filter) {
          return ChoiceChip(
            label: Text(filter),
            selected: _selectedFilter == filter,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    return GestureDetector(
      onTap: () {
        if (complaint.status != ComplaintStatus.pending) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ComplaintDetailsPage(complaint: complaint)),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(complaint.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildStatusBadge(complaint.status),
                ],
              ),
              const SizedBox(height: 8),
              Text('Student: ${complaint.student} | Room: ${complaint.room}'),
              Text('Category: ${complaint.category} | Priority: ${complaint.priority}'),
              const SizedBox(height: 4),
              Text('Submitted: ${complaint.submitted}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              if (complaint.status == ComplaintStatus.pending)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Assign Technician'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AssignTechnicianPage(complaint: complaint)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

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
