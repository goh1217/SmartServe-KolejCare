import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // Assuming image_picker is available or I will add logic.
import 'package:http/http.dart' as http;
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
  String scheduledTime = '--:--';
  String title = 'Loading...';
  String location = 'Loading...';
  String description = 'Loading...';
  String assignmentNotes = 'Loading...'; // Rejection reason or notes
  String studentName = 'Loading...';
  String studentRole = 'Student'; // Assuming student for now
  String studentImage = 'https://via.placeholder.com/150';
  String studentPhoneNumber = ''; // Phone number for calling
  List<String> damagePictures = []; // List to store multiple damage pictures
  int currentImageIndex = 0; // Track current image being displayed
  String studentId = '';
  
  // For proof submission
  String? proofImage; // Placeholder for proof image URL or path logic if implemented

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
          title = data['inventoryDamageTitle'] ?? 'No title provided.';
          location = data['damageLocation'] ?? 'No location provided.';
          description = data['inventoryDamage'] ?? 'No description provided.';
          assignmentNotes = data['rejectionReason'] ?? 'No notes provided.';
          // If there is a damagePic field - can be a string or list
          if (data['damagePic'] != null) {
            if (data['damagePic'] is List) {
              damagePictures = List<String>.from(data['damagePic'] as List);
            } else if (data['damagePic'] is String) {
              damagePictures = [data['damagePic'] as String];
            }
            currentImageIndex = 0; // Reset to first image
          }
          // If there is a proof pic
          if (data['proofPic'] != null) {
            proofImage = data['proofPic'];
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
              // Convert stored timestamp to UTC then apply UTC+8 (Malaysia timezone)
              final dt = timestamp.toDate().toUtc().add(const Duration(hours: 8));
              date = "${dt.day}/${dt.month}/${dt.year}";
              // Also set scheduled time if scheduledDate provided
              final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
              final minute = dt.minute.toString().padLeft(2, '0');
              final ampm = dt.hour < 12 ? 'AM' : 'PM';
              scheduledTime = '$hour:$minute $ampm';
          } else {
            date = widget.time;
          }

          // Fetch Student Info from studentID or matricNo in complaint
          final String? studentIDFromComplaint = data['studentID'] ?? data['matricNo'];
          if (studentIDFromComplaint != null && studentIDFromComplaint.isNotEmpty) {
            _fetchStudentInfoById(studentIDFromComplaint);
          } else {
            // Fallback to reportBy if studentID not available
            final String? reportByPath = data['reportBy'];
            if (reportByPath != null) {
               _fetchStudentInfo(reportByPath);
            }
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
             studentName = studentData['studentName'] ?? 'Unknown Student';
             // studentImage = studentData['profileImage'] ?? studentImage; 
             // studentRole = 'Student'; 
           });
         }
      }
    } catch (e) {
      print("Error fetching student info: $e");
    }
  }

  Future<void> _fetchStudentInfoById(String studentID) async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(studentID)
          .get();

      if (studentDoc.exists) {
        final studentData = studentDoc.data() as Map<String, dynamic>;
        setState(() {
          studentId = studentID;
          // Try to get name from different possible fields, fallback to matricNo
          studentName = studentData['studentName'] ?? 
                       studentData['matricNo'] ?? 
                       'Unknown Student';
          // Phone field is 'phoneNo' in the student collection
          studentPhoneNumber = studentData['phoneNo'] ?? 
                              studentData['phoneNumber'] ?? 
                              studentData['phone'] ?? 
                              '';
          // Get student image if available
          if (studentData['photoUrl'] != null) {
            studentImage = studentData['photoUrl'] as String;
          }
        });
      }
    } catch (e) {
      print("Error fetching student info by ID: $e");
    }
  }

  Future<void> _callStudent() async {
  if (studentPhoneNumber.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Student phone number not available')),
    );
    return;
  }

  final sanitizedPhoneNumber = studentPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

  if (sanitizedPhoneNumber.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid phone number format')),
    );
    return;
  }

  final Uri launchUri = Uri(
    scheme: 'tel',
    path: sanitizedPhoneNumber,
  );

  try {
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  } catch (e) {
    print("Error launching phone call: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

  Future<String?> uploadToCloudinary(File file) async {
    const cloudName = "deaju8keu";
    const uploadPreset = "flutter upload";

    final url =
        "https://api.cloudinary.com/v1_1/$cloudName/image/upload";

    final request = http.MultipartRequest("POST", Uri.parse(url))
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final resString = await response.stream.bytesToString();
    final jsonData = json.decode(resString);

    if (jsonData["secure_url"] != null) {
      return jsonData["secure_url"];
    }
    return null;
  }

  Future<File?> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      return File(picked.path);
    }
    return null;
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
                          title,
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
                            _buildInfoItem('Address', location),
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
                                  scheduledTime != '--:--' ? scheduledTime : widget.time,
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
                    'Damaged Images',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (damagePictures.isNotEmpty)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Left arrow button
                            if (damagePictures.length > 1)
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios),
                                onPressed: () {
                                  setState(() {
                                    currentImageIndex = (currentImageIndex - 1 + damagePictures.length) % damagePictures.length;
                                  });
                                },
                              )
                            else
                              const SizedBox(width: 48),
                            // Image display
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  damagePictures[currentImageIndex],
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
                            ),
                            // Right arrow button
                            if (damagePictures.length > 1)
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: () {
                                  setState(() {
                                    currentImageIndex = (currentImageIndex + 1) % damagePictures.length;
                                  });
                                },
                              )
                            else
                              const SizedBox(width: 48),
                          ],
                        ),
                        // Image counter
                        if (damagePictures.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${currentImageIndex + 1} / ${damagePictures.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 160,
                        height: 120,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image, size: 50),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            
            // Proof submission display if completed
            if (proofImage != null)
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
                      'Submit proof photo of completed task',
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
                        proofImage!,
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
            
            if (proofImage != null) const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildActionButton(),
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
                          studentPhoneNumber.isEmpty ? 'Phone: Not available' : 'Phone: $studentPhoneNumber',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
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
                  GestureDetector(
                    onTap: _callStudent,
                    child: Container(
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

  Widget _buildActionButton() {
    // Check if status is In Progress (case insensitive)
    bool isInProgress = status.toLowerCase() == 'in progress' || status.toLowerCase() == 'ongoing';
    bool isCompleted = status.toLowerCase() == 'completed';

    if (isCompleted) {
      return const SizedBox.shrink(); // Button disappears when completed
    }

    if (isInProgress) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            // Step 1: pick image
            File? image = await pickImage();

            if (image == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No image selected.")),
              );
              return;
            }

            // Step 2: show confirmation preview
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Submit proof image'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Please confirm the image before submitting.'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Image.file(image, fit: BoxFit.cover),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
                ],
              ),
            );

            if (confirm != true) {
              // user cancelled
              return;
            }

            // Show uploading indicator
            ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Uploading image...")),
            );

            String? url = await uploadToCloudinary(image);

            if (url == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Image upload failed.")),
              );
              return;
            }

            await FirebaseFirestore.instance
                .collection("complaint")
                .doc(widget.taskId)
                .update({
              'proofPic': url,
              'reportStatus': "Completed",
            });

            setState(() {
              proofImage = url; // Update the displayed proof image
              status = "Completed";
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Task marked as completed with image.")),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853), // Green color for completed
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: const Text(
            'Complete Task',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      // Default state: Start Repair
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            _showStartRepairDialog();
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
      );
    }
  }

  void _showStartRepairDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.build, // Wrench icon
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Are you sure you want to start your repair task?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        _updateComplaintStatus('Ongoing');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F), // Red
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Yes',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700], // Dark Grey
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'No',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateComplaintStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.taskId)
          .update({'reportStatus': newStatus});
      
      setState(() {
        status = newStatus;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFA726);
      case 'in progress':
      case 'ongoing':
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

// Removed ProofSubmissionDialog since we are using direct upload flow in the button now
