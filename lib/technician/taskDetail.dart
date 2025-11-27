import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // For navigation if needed
import 'calendar.dart'; // For navigation if needed
import 'profile.dart'; // For navigation if needed

class TaskDetailPage extends StatefulWidget {
  final String taskId;
  // Basic info passed for immediate display (hero animation or quick load)
  // We will fetch the full details in this page.
  final String title;
  final String location;
  final String time;
  final String status;

  const TaskDetailPage({
    super.key,
    required this.taskId,
    required this.title,
    required this.location,
    required this.time,
    this.status = 'PENDING',
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  int selectedNavIndex = 0;

  // Data fields
  String status = 'Loading...';
  String urgency = 'Loading...';
  String category = 'Loading...';
  String date = 'Loading...';
  String description = 'Loading...';
  String assignmentNotes = 'Loading...'; // Rejection reason or notes
  String studentName = 'Loading...';
  String studentRole = 'Student'; // Assuming student for now
  String studentImage = 'https://via.placeholder.com/150';
  String taskImage = 'https://via.placeholder.com/300x200';
  String studentId = '';

  @override
  void initState() {
    super.initState();
    status = widget.status; // Initialize with passed status
    _fetchComplaintDetails();
  }

  Future<void> _fetchComplaintDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.taskId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          status = data['reportStatus'] ?? widget.status;
          urgency = data['urgencyLevel'] ?? 'Medium';
          category = data['damageCategory'] ?? 'Uncategorized';
          description = data['inventoryDamage'] ?? 'No description provided.';
          assignmentNotes = data['rejectionReason'] ?? 'No notes provided.';
          // If there is a damagePic field
          if (data['damagePic'] != null) {
             taskImage = data['damagePic'];
          }

          // Date handling
          Timestamp? timestamp;
          if (data['scheduledDate'] != null) {
            timestamp = data['scheduledDate'] as Timestamp;
          } else if (data['scheduledDate'] != null) {
            timestamp = data['scheduledDate'] as Timestamp;
          } else if (data['reportedDate'] != null) {
            timestamp = data['reportedDate'] as Timestamp;
          }

          if (timestamp != null) {
            // Convert to local time (or UTC+8 if we strictly followed the previous fix, 
            // but usually Detail view can show standard local format)
            final dt = timestamp.toDate();
            date = "${dt.day}/${dt.month}/${dt.year}";
          } else {
            date = widget.time;
          }

          // Fetch Student Info
          // The 'reportBy' field is a String path "/collection/student/..."
          // We need to extract the ID or use the path directly if we can parse it.
          final String? reportByPath = data['reportBy'];
          if (reportByPath != null) {
             _fetchStudentInfo(reportByPath);
          }
        });
      }
    } catch (e) {
      print("Error fetching task details: $e");
    }
  }

  Future<void> _fetchStudentInfo(String studentPath) async {
    try {
      // studentPath example: "/collection/student/StudentId123"
      // We can try to get the document directly if we split it or just use doc reference if it was a reference.
      // Since the prompt says it's a String: "/collection/student", wait, usually it's "student/ID".
      // If the prompt says "/collection/student", maybe it meant the COLLECTION path, but typically it should be a document path.
      // Let's assume it holds the path to the student document.
      // If it's just "/collection/student", we can't find the specific student.
      // Assuming it's a valid path to a document:
      
      // Clean up path if it starts with /
      String path = studentPath;
      if (path.startsWith('/')) path = path.substring(1);
      
      // Firestore cannot get document from just collection path. 
      // If the data provided in prompt example was literally just "/collection/student", it's incomplete.
      // Assuming it might be "student/STUDENT_ID".
      // Let's try to just split and see.
      
      // If we can't fetch, we leave as Loading.
      // However, typically we might have 'StudentId' field.
      // In the provided class attributes:
      // reportBy "/collection/student" (string)
      // This looks like a placeholder string in the prompt example.
      // If real data has "student/b70..." then we can fetch.
      
      // For now, I will try to fetch if it looks like a doc path (even number of segments).
      final segments = path.split('/');
      if (segments.length % 2 == 0 && segments.isNotEmpty) {
         final studentDoc = await FirebaseFirestore.instance.doc(path).get();
         if (studentDoc.exists) {
           final studentData = studentDoc.data() as Map<String, dynamic>;
           setState(() {
             studentName = studentData['name'] ?? 'Unknown Student';
             // studentImage = studentData['profileImage'] ?? studentImage; 
             // studentRole = 'Student'; 
           });
         }
      }
    } catch (e) {
      print("Error fetching student info: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Task detail',
          style: TextStyle(
            color: Color(0xFF1A3A3A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Main Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Details Grid
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoItem('Complaint ID', widget.taskId),
                            const SizedBox(height: 16),
                            _buildInfoItem('Category', category),
                            const SizedBox(height: 16),
                            _buildInfoItem('Address', widget.location),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoItem('Urgency', urgency),
                            const SizedBox(height: 16),
                            _buildInfoItem('Scheduled time', ''),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.time, // Time passed from list might be sufficient
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  date,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Description Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Images',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      taskImage,
                      width: 160,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 160,
                          height: 120,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image, size: 50),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Assignment Notes / Rejection Reason Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notes / Rejection Reason',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    assignmentNotes,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement start repair functionality
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Start Repair',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // Navigate to Calendar
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const CalendarPage()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.grey, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'View on calendar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Student Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundImage: NetworkImage(studentImage),
                    onBackgroundImageError: (exception, stackTrace) {
                      // Handle error silently
                    },
                    child: studentImage.contains('placeholder')
                        ? const Icon(Icons.person, size: 35)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          studentRole,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavIcon(Icons.home_rounded, 0),
              _buildNavIcon(Icons.calendar_today, 1),
              _buildNavIcon(Icons.people, 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        if (value.isNotEmpty)
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildNavIcon(IconData icon, int index) {
    final isSelected = selectedNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedNavIndex = index;
        });
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TechnicianDashboard()),
          );
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CalendarPage()),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey.shade400,
          size: 26,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFA726);
      case 'in progress':
        return const Color(0xFF42A5F5);
      case 'completed':
        return const Color(0xFF66BB6A);
      case 'rejected':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF7D6E3A);
    }
  }
}
