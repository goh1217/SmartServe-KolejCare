import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // Assuming image_picker is available or I will add logic.
import 'package:http/http.dart' as http;
import '../services/technician_task_service.dart';
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
  
  // For arrived tracking
  DateTime? arrivedAt; // Timestamp when technician arrived
  
  // Location coordinates for Google Maps
  double? locationLatitude;
  double? locationLongitude;
  
  // For proof submission
  List<String> proofImages = []; // List to store up to 3 proof images
  int currentProofImageIndex = 0; // Track current proof image being displayed
  
  // For can't complete submission
  List<String> reasonCantCompleteProofList = []; // List to store up to 3 proof images
  int currentReasonImageIndex = 0; // Track current reason image being displayed
  String reasonCantCompleteText = '';

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
          
          // Load location coordinates if available
          if (data['repairLocation'] != null) {
            final geoPoint = data['repairLocation'];
            locationLatitude = geoPoint.latitude;
            locationLongitude = geoPoint.longitude;
            print('DEBUG taskDetail: Loaded repairLocation coordinates: $locationLatitude, $locationLongitude');
          } else if (data['damageLocationCoordinates'] != null) {
            // Fallback to old field for backward compatibility
            final geoPoint = data['damageLocationCoordinates'];
            locationLatitude = geoPoint.latitude;
            locationLongitude = geoPoint.longitude;
            print('DEBUG taskDetail: Loaded damageLocationCoordinates (fallback): $locationLatitude, $locationLongitude');
          }
          
          // Load arrivedAt timestamp if it exists
          if (data['arrivedAt'] != null && data['arrivedAt'] is Timestamp) {
            arrivedAt = (data['arrivedAt'] as Timestamp).toDate();
          }
          
          // If there is a damagePic field - can be a string or list
          if (data['damagePic'] != null) {
            if (data['damagePic'] is List) {
              damagePictures = List<String>.from(data['damagePic'] as List);
            } else if (data['damagePic'] is String) {
              damagePictures = [data['damagePic'] as String];
            }
            currentImageIndex = 0; // Reset to first image
          }
          // If there is a proof pic - can be a string or list
          if (data['proofPic'] != null) {
            if (data['proofPic'] is List) {
              proofImages = List<String>.from(data['proofPic'] as List);
            } else if (data['proofPic'] is String) {
              proofImages = [data['proofPic'] as String];
            }
            currentProofImageIndex = 0; // Reset to first image
          }
          
          // If there is a reason can't complete proof - can be a string or list
          if (data['reasonCantCompleteProof'] != null) {
            if (data['reasonCantCompleteProof'] is List) {
              reasonCantCompleteProofList = List<String>.from(data['reasonCantCompleteProof'] as List);
            } else if (data['reasonCantCompleteProof'] is String) {
              reasonCantCompleteProofList = [data['reasonCantCompleteProof'] as String];
            }
            currentReasonImageIndex = 0; // Reset to first image
          }
          
          // Load reason can't complete text
          reasonCantCompleteText = data['reasonCantComplete'] ?? '';

          // Date handling - try scheduledDateTimeSlot first (new format)
          if (data['scheduledDateTimeSlot'] != null && data['scheduledDateTimeSlot'] is List) {
            final slots = (data['scheduledDateTimeSlot'] as List).cast<Timestamp>();
            if (slots.isNotEmpty) {
              // Use first slot for date and time
              final firstSlot = slots[0];
              final dt = TimeSlotHelper.toMalaysiaTime(firstSlot);
              date = "${dt.day}/${dt.month}/${dt.year}";
              
              // Format the time range from slots
              final timeRange = TimeSlotHelper.formatTimeSlots(slots, includeDate: false);
              scheduledTime = timeRange ?? '--:--';
            }
          } else {
            // Fallback to old format
            Timestamp? timestamp;
            if (data['scheduledDate'] != null) {
              timestamp = data['scheduledDate'] as Timestamp;
            } else if (data['reportedDate'] != null) {
              timestamp = data['reportedDate'] as Timestamp;
            }

            if (timestamp != null) {
              // Interpret stored timestamp as Malaysia time
              final dt = TimeSlotHelper.toMalaysiaTime(timestamp);
              date = "${dt.day}/${dt.month}/${dt.year}";
              // Also set scheduled time if scheduledDate provided
              final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
              final minute = dt.minute.toString().padLeft(2, '0');
              final ampm = dt.hour < 12 ? 'AM' : 'PM';
              scheduledTime = '$hour:$minute $ampm';
            } else {
              date = widget.time;
            }
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Split multiple time slots into separate lines
                                      ...(scheduledTime != '--:--' ? scheduledTime.split(', ') : [widget.time]).map(
                                        (timeSlot) => Padding(
                                          padding: const EdgeInsets.only(bottom: 4.0),
                                          child: Text(
                                            timeSlot,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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

            // Google Maps Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openLocationInGoogleMaps,
                  icon: const Icon(Icons.map),
                  label: const Text('Open Location in Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
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
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => FullScreenImageViewer(
                                        imageUrl: damagePictures[currentImageIndex],
                                        images: damagePictures,
                                        initialIndex: currentImageIndex,
                                      ),
                                    ),
                                  );
                                },
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
            if (proofImages.isNotEmpty)
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
                    if (proofImages.length == 1)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageViewer(
                                imageUrl: proofImages[0],
                                images: proofImages,
                                initialIndex: 0,
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            proofImages[0],
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 200,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image, size: 50),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Left arrow button
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios),
                                onPressed: () {
                                  setState(() {
                                    currentProofImageIndex = (currentProofImageIndex - 1 + proofImages.length) % proofImages.length;
                                  });
                                },
                              ),
                              // Image display
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => FullScreenImageViewer(
                                          imageUrl: proofImages[currentProofImageIndex],
                                          images: proofImages,
                                          initialIndex: currentProofImageIndex,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      proofImages[currentProofImageIndex],
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: double.infinity,
                                          height: 200,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.image, size: 50),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              // Right arrow button
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: () {
                                  setState(() {
                                    currentProofImageIndex = (currentProofImageIndex + 1) % proofImages.length;
                                  });
                                },
                              ),
                            ],
                          ),
                          // Image counter
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${currentProofImageIndex + 1} / ${proofImages.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            
            if (proofImages.isNotEmpty) const SizedBox(height: 16),

            // Reason Can't Complete display if incomplete
            if (reasonCantCompleteProofList.isNotEmpty)
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
                      'Reason for Incomplete Task',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reasonCantCompleteText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Proof Photos',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (reasonCantCompleteProofList.length == 1)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageViewer(
                                imageUrl: reasonCantCompleteProofList[0],
                                images: reasonCantCompleteProofList,
                                initialIndex: 0,
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            reasonCantCompleteProofList[0],
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 200,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image, size: 50),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Left arrow button
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios),
                                onPressed: () {
                                  setState(() {
                                    currentReasonImageIndex = (currentReasonImageIndex - 1 + reasonCantCompleteProofList.length) % reasonCantCompleteProofList.length;
                                  });
                                },
                              ),
                              // Image display
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => FullScreenImageViewer(
                                          imageUrl: reasonCantCompleteProofList[currentReasonImageIndex],
                                          images: reasonCantCompleteProofList,
                                          initialIndex: currentReasonImageIndex,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      reasonCantCompleteProofList[currentReasonImageIndex],
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: double.infinity,
                                          height: 200,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.image, size: 50),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              // Right arrow button
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: () {
                                  setState(() {
                                    currentReasonImageIndex = (currentReasonImageIndex + 1) % reasonCantCompleteProofList.length;
                                  });
                                },
                              ),
                            ],
                          ),
                          // Image counter
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${currentReasonImageIndex + 1} / ${reasonCantCompleteProofList.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            
            if (reasonCantCompleteProofList.isNotEmpty) const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildActionButton(),
                  if (status.toLowerCase() != 'pending') ...[
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Student Info Card
            if (status.toLowerCase() != 'pending')
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
    // Check task status
    bool isCompleted = status.toLowerCase() == 'completed';
    bool isPending = status.toLowerCase() == 'pending';
    bool isOngoing = status.toLowerCase() == 'ongoing';
    bool hasArrived = arrivedAt != null;

    if (isCompleted || isPending) {
      return const SizedBox.shrink(); // Button disappears when completed or pending
    }

    // State 1: Show "Start Task" button when task is not yet ongoing
    if (!isOngoing && !hasArrived) {
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
            'Start Task',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // State 2: Show "Arrive" button when task is ongoing but not yet arrived
    if (isOngoing && !hasArrived) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            _showArriveDialog();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: const Text(
            'Arrive',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // State 3: Show "Complete Task" and "Can't Complete" buttons once arrived
    if (hasArrived) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                _showCompleteTaskDialog();
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
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showCantCompleteDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350), // Red color for can't complete
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                "Can't Complete",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _openLocationInGoogleMaps() async {
    print('DEBUG: _openLocationInGoogleMaps called');
    print('DEBUG: locationLatitude = $locationLatitude');
    print('DEBUG: locationLongitude = $locationLongitude');
    
    if (locationLatitude == null || locationLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }

    final url =
        'https://www.google.com/maps/search/?api=1&query=$locationLatitude,$locationLongitude';
    
    print('DEBUG: Google Maps URL = $url');

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch Google Maps')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
                        _setStatusToOngoing(); // Change status to ONGOING
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

  void _showCompleteTaskDialog() {
    List<String> tempProofImages = [];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C853),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Complete Task',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Text(
                              'Upload proof photos (up to 3)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Image Upload Section
                  const Text(
                    'Proof Photos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Display uploaded images with delete option
                  if (tempProofImages.isNotEmpty)
                    Column(
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(tempProofImages.length, (index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(tempProofImages[index]),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        tempProofImages.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  
                  // Add more images button (if less than 3)
                  if (tempProofImages.length < 3)
                    GestureDetector(
                      onTap: () async {
                        File? image = await pickImage();
                        if (image != null) {
                          setDialogState(() {
                            tempProofImages.add(image.path);
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to upload image (${tempProofImages.length}/3)',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (tempProofImages.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please upload at least one proof image'),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(context);
                            await _submitCompleteTask(tempProofImages);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Submit',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitCompleteTask(List<String> imagePaths) async {
    try {
      // Show uploading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading proof images...")),
      );

      // Upload all images to Cloudinary
      List<String> uploadedUrls = [];
      for (int i = 0; i < imagePaths.length; i++) {
        String? url = await uploadToCloudinary(File(imagePaths[i]));
        if (url != null) {
          uploadedUrls.add(url);
        }
      }

      if (uploadedUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image upload failed.")),
        );
        return;
      }

      // Update complaint in Firestore with array of images
      await FirebaseFirestore.instance
          .collection("complaint")
          .doc(widget.taskId)
          .update({
        'proofPic': uploadedUrls,
        'reportStatus': "Completed",
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'isRead': false,
        'statusChangeCount': FieldValue.increment(1),
      });

      setState(() {
        proofImages = uploadedUrls;
        currentProofImageIndex = 0;
        status = "Completed";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task marked as completed with proof images.")),
      );
    } catch (e) {
      print("Error submitting complete task: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showCantCompleteDialog() {
    List<String> tempReasonProofImages = [];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF5350),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cannot Complete Task',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Text(
                              'Please provide reason and proof photos',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Reason Text Field
                  const Text(
                    'Reason for incomplete task',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (value) {
                      reasonCantCompleteText = value;
                    },
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Explain why you cannot complete this task...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Upload Section
                  const Text(
                    'Proof Photos (up to 3)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Display uploaded images with delete option
                  if (tempReasonProofImages.isNotEmpty)
                    Column(
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(tempReasonProofImages.length, (index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(tempReasonProofImages[index]),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        tempReasonProofImages.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  
                  // Add more images button (if less than 3)
                  if (tempReasonProofImages.length < 3)
                    GestureDetector(
                      onTap: () async {
                        File? image = await pickImage();
                        if (image != null) {
                          setDialogState(() {
                            tempReasonProofImages.add(image.path);
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to upload image (${tempReasonProofImages.length}/3)',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (reasonCantCompleteText.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please provide a reason'),
                                ),
                              );
                              return;
                            }

                            if (tempReasonProofImages.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please upload at least one proof image'),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(context);
                            await _submitCantCompleteTask(tempReasonProofImages);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF5350),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Submit',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitCantCompleteTask(List<String> imagePaths) async {
    try {
      // Show uploading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading proof images...")),
      );

      // Upload all images to Cloudinary
      List<String> uploadedUrls = [];
      for (int i = 0; i < imagePaths.length; i++) {
        String? url = await uploadToCloudinary(File(imagePaths[i]));
        if (url != null) {
          uploadedUrls.add(url);
        }
      }

      if (uploadedUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image upload failed.")),
        );
        return;
      }

      // Update complaint in Firestore with array of images
      await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.taskId)
          .update({
        'reasonCantCompleteProof': uploadedUrls,
        'reasonCantComplete': reasonCantCompleteText,
        'reportStatus': 'Pending',
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'isRead': false,
        'statusChangeCount': FieldValue.increment(1),
        'cantCompleteCount': FieldValue.increment(1),
      });

      // Send notification to student
      await _sendNotificationToStudent();

      setState(() {
        status = 'Pending';
        reasonCantCompleteProofList = uploadedUrls;
        currentReasonImageIndex = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task marked as incomplete. Student and admin have been notified.'),
        ),
      );
    } catch (e) {
      print("Error submitting can't complete task: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _sendNotificationToStudent() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.taskId)
          .get();

      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final String? studentID = data['studentID'] ?? data['matricNo'];

      if (studentID != null && studentID.isNotEmpty) {
        // Get student document to find their notification collection
        final studentDoc = await FirebaseFirestore.instance
            .collection('student')
            .doc(studentID)
            .get();

        if (studentDoc.exists) {
          // Create notification in student's notification collection
          await FirebaseFirestore.instance
              .collection('student')
              .doc(studentID)
              .collection('notifications')
              .add({
            'title': 'Task Incomplete - Reassignment Pending',
            'message': 'Your maintenance task cannot be completed by the assigned technician. An admin will reassign this task to another technician. Please wait for further updates.',
            'complaintId': widget.taskId,
            'type': 'task_incomplete',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

          print('Notification sent to student: $studentID');
        }
      }
    } catch (e) {
      print("Error sending notification to student: $e");
    }
  }

  Future<void> _setStatusToOngoing() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      print('DEBUG _setStatusToOngoing: Starting task for user.uid=${user.uid}, task=${widget.taskId}');

      // Use TechnicianTaskService to start the task with GPS tracking
      final taskService = TechnicianTaskService();
      await taskService.startTask(widget.taskId, user.uid);
      
      // Increment statusChangeCount
      await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.taskId)
          .update({
            'statusChangeCount': FieldValue.increment(1),
          });
      
      setState(() {
        status = 'Ongoing';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task started! GPS tracking enabled. Click Arrive when you reach the location.')),
      );
    } catch (e) {
      print('Error starting task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start task: $e')),
      );
    }
  }

  void _showArriveDialog() {
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
                  color: Color(0xFF2196F3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Have you arrived at the repair location?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _setArrivedAt();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50), // Green
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
                        backgroundColor: Colors.grey[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Not Yet',
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

  Future<void> _setArrivedAt() async {
    try {
      await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.taskId)
          .update({
            'arrivedAt': FieldValue.serverTimestamp(),
            'statusChangeCount': FieldValue.increment(1),
          });
      
      setState(() {
        arrivedAt = DateTime.now();
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task started! You can now proceed.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start task: $e')),
      );
    }
  }

  Future<void> _updateComplaintStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.taskId)
          .update({
            'reportStatus': newStatus,
            'lastStatusUpdate': FieldValue.serverTimestamp(),
            'isRead': false,
            'statusChangeCount': FieldValue.increment(1),
          });
      
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

// Full-screen image viewer with zoom capability
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final List<String> images;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late int currentIndex;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _nextImage() {
    if (currentIndex < widget.images.length - 1) {
      setState(() {
        currentIndex++;
        _resetZoom();
      });
    }
  }

  void _previousImage() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        _resetZoom();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetZoom,
            tooltip: 'Reset zoom',
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTap: _resetZoom,
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(80),
          minScale: 1.0,
          maxScale: 5.0,
          child: Center(
            child: Image.network(
              widget.images[currentIndex],
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 50),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.images.length > 1
          ? BottomAppBar(
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: currentIndex > 0 ? _previousImage : null,
                    disabledColor: Colors.grey,
                  ),
                  Text(
                    '${currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                    onPressed: currentIndex < widget.images.length - 1 ? _nextImage : null,
                    disabledColor: Colors.grey,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

// Removed ProofSubmissionDialog since we are using direct upload flow in the button now
