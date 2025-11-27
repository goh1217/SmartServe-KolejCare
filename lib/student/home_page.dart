import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:owtest/student/complaint_form_screen.dart';
import 'services/weatherService.dart';

import 'notification_page.dart';
import 'donate_page.dart';
import 'screens/activity.dart';

// Simple model to hold complaint summary information for UI
class ComplaintSummary {
  final String id;
  final String rawStatus;
  final double progress;
  final String displayText;
  final String description;
  final String category;
  final int? createdAt;

  ComplaintSummary({
    required this.id,
    required this.rawStatus,
    required this.progress,
    required this.displayText,
    required this.description,
    required this.category,
    this.createdAt,
  });
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showAlert = true;
  WeatherData? weatherData;
  bool isLoadingWeather = true;
  String weatherError = '';
  // Firestore fields
  String studentName = '';
  String matricNo = '';
  bool isLoadingStudent = true;

  // Complaint progress
  double complaintProgress = 0.0; // 0.0 - 1.0
  String complaintStatusLabel = 'No reports';
  String complaintStatusDescription = '';
  // raw status value from complaint doc (lowercase) for logic decisions
  String complaintRawStatus = '';
  // damage category from complaint doc (e.g. "Electrical", "Furniture")
  String complaintDamageCategory = '';
  // List of complaint summaries for multi-complaint support
  List<ComplaintSummary> complaintSummaries = [];

  @override
  void initState() {
    super.initState();
    _loadWeather();
    _loadComplaintProgress();
    fetchStudentData();
  }

  // Small status bar widget that reflects complaint progress and status
  Widget _buildStatusBar() {
    final label = complaintStatusLabel.replaceAll('\n', ' ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        complaintStatusDescription,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        '${(complaintProgress * 100).round()}%',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: complaintProgress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        complaintProgress >= 1.0
                            ? Colors.green
                            : (complaintRawStatus.contains('rejected') ? Colors.red : Colors.deepPurple),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Show damage/category on the right so student knows which complaint this refers to
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                complaintDamageCategory.isNotEmpty ? complaintDamageCategory : 'No category',
                style: TextStyle(
                  color: complaintDamageCategory.isNotEmpty ? Colors.deepPurple : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a status bar for a specific complaint summary
  Widget _buildStatusBarFor(ComplaintSummary c) {
    final label = c.displayText.replaceAll('\n', ' ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 6)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.description, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('${(c.progress * 100).round()}%', style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: c.progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        c.progress >= 1.0 ? Colors.green : (c.rawStatus.contains('rejected') ? Colors.red : Colors.deepPurple),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                c.category.isNotEmpty ? c.category : 'No category',
                style: TextStyle(
                  color: c.category.isNotEmpty ? Colors.deepPurple : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build a ComplaintSummary from a Firestore doc map
  ComplaintSummary _buildSummaryFromDoc(String id, Map<String, dynamic> data) {
    final statusRaw = (data['status'] ?? data['reportStatus'] ?? data['Status'] ?? data['ReportStatus'] ?? '').toString();
    final status = statusRaw.trim();
    final s = status.toLowerCase();

    double progress = 0.0;
    String displayText = '';

    if (s == 'submitted') {
      progress = 0.15;
      displayText = 'Report Submitted';
    } else if (s == 'pending') {
      progress = 0.30;
      displayText = 'Under Review';
    } else if (s == 'reviewed') {
      progress = 0.50;
      displayText = 'Being Reviewed';
    } else if (s.contains('approved') || s == 'approved') {
      progress = 0.70;
      displayText = 'Report Approved';
    } else if (s == 'rejected') {
      progress = 0.70;
      displayText = 'Report Rejected';
    } else if (s == 'assigned') {
      progress = 0.90;
      displayText = 'Technician On The Way';
    } else if (s == 'completed') {
      progress = 1.0;
      displayText = 'Work Completed';
    } else {
      progress = 0.0;
      displayText = status.isNotEmpty ? status : 'No Reports';
    }

    final categoryRaw = (data['damageCategory'] ?? data['damage_category'] ?? data['category'] ?? data['damage'] ?? '').toString();
    final category = categoryRaw.isNotEmpty ? categoryRaw : '';

    int? createdMs;
    final createdVal = data['createdAt'] ?? data['timestamp'] ?? data['created'];
    if (createdVal != null) {
      if (createdVal is int) createdMs = createdVal;
      else if (createdVal is double) createdMs = createdVal.toInt();
      else if (createdVal is String) {
        createdMs = int.tryParse(createdVal);
      } else if (createdVal is Timestamp) {
        createdMs = createdVal.millisecondsSinceEpoch;
      }
    }

    return ComplaintSummary(
      id: id,
      rawStatus: s,
      progress: progress,
      displayText: displayText,
      description: '${(progress * 100).round()}%',
      category: category,
      createdAt: createdMs,
    );
  }

  Future<void> _loadComplaintProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;

      if (kDebugMode) print('Loading complaint progress for user uid: $uid');

      if (uid == null) {
        if (kDebugMode) print('No user logged in');
        setState(() {
          complaintSummaries = [];
          complaintProgress = 0.0;
          complaintStatusLabel = 'No reports';
          complaintStatusDescription = '';
          complaintRawStatus = '';
          complaintDamageCategory = '';
        });
        return;
      }

      // Find the student document for this user (we assume student doc has an 'authUid' or uses same email)
      final studentQuery = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();

      String? studentDocId;
      if (studentQuery.docs.isNotEmpty) {
        studentDocId = studentQuery.docs.first.id;
      } else {
        // fallback: try matching by email if authUid not present
        final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        if (userEmail.isNotEmpty) {
          final byEmail = await FirebaseFirestore.instance
              .collection('student')
              .where('email', isEqualTo: userEmail)
              .limit(1)
              .get();
          if (byEmail.docs.isNotEmpty) studentDocId = byEmail.docs.first.id;
        }
      }

      // Query complaints where reportBy equals the student doc id (preferred) or the auth uid
      final Set<String> complaintIds = <String>{};
      final List<ComplaintSummary> summaries = [];

      if (studentDocId != null && studentDocId.isNotEmpty) {
        final studentRef = FirebaseFirestore.instance.collection('student').doc(studentDocId);

        // First try where reportBy is stored as a DocumentReference
        final qRef = await FirebaseFirestore.instance
            .collection('complaint')
            .where('reportBy', isEqualTo: studentRef)
            .get();
        for (final d in qRef.docs) {
          complaintIds.add(d.id);
          summaries.add(_buildSummaryFromDoc(d.id, d.data()));
        }

        // Some systems store the reportBy as a path/string. Try common variants.
        final pathVariants = [
          'student/$studentDocId',
          '/student/$studentDocId',
          'collection/student/$studentDocId',
          '/collection/student/$studentDocId',
          studentDocId,
        ];
        for (final variant in pathVariants) {
          if (variant.isEmpty) continue;
          final qS = await FirebaseFirestore.instance
              .collection('complaint')
              .where('reportBy', isEqualTo: variant)
              .get();
          for (final d in qS.docs) {
            if (!complaintIds.contains(d.id)) {
              complaintIds.add(d.id);
              summaries.add(_buildSummaryFromDoc(d.id, d.data()));
            }
          }
        }
      }

      // also check where reportBy equals auth uid (some apps store auth uid)
      final q2 = await FirebaseFirestore.instance.collection('complaint').where('reportBy', isEqualTo: uid).get();
      for (final d in q2.docs) {
        if (!complaintIds.contains(d.id)) {
          complaintIds.add(d.id);
          summaries.add(_buildSummaryFromDoc(d.id, d.data()));
        }
      }

      // If still empty, fall back to complaints referenced in student doc fields (complaintId(s))
      if (summaries.isEmpty && studentDocId != null) {
        final studentDoc = await FirebaseFirestore.instance.collection('student').doc(studentDocId).get();
        final studentData = studentDoc.data() ?? {};
        final singleId = (studentData['complaintID'] ?? studentData['complaintId'] ?? studentData['complaint'] ?? '').toString();
        if (singleId.isNotEmpty) complaintIds.add(singleId);
        final listField = studentData['complaintIds'] ?? studentData['complaintList'] ?? studentData['complaints'];
        if (listField is List) {
          for (final item in listField) {
            final sId = item?.toString() ?? '';
            if (sId.isNotEmpty) complaintIds.add(sId);
          }
        }
        for (final id in complaintIds) {
          final doc = await FirebaseFirestore.instance.collection('complaint').doc(id).get();
          if (doc.exists) summaries.add(_buildSummaryFromDoc(doc.id, doc.data() ?? {}));
        }
      }

      if (summaries.isEmpty) {
        setState(() {
          complaintSummaries = [];
          complaintProgress = 0.0;
          complaintStatusLabel = 'No reports';
          complaintStatusDescription = '';
          complaintRawStatus = '';
          complaintDamageCategory = '';
        });
        return;
      }

      // sort by createdAt descending
      summaries.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));

      final primary = summaries.first;
      setState(() {
        complaintSummaries = summaries;
        complaintProgress = primary.progress;
        complaintStatusLabel = primary.displayText;
        complaintRawStatus = primary.rawStatus;
        complaintStatusDescription = primary.description;
        complaintDamageCategory = primary.category;
      });

      final anyAssigned = summaries.any((c) => c.rawStatus == 'assigned');
      if (anyAssigned && showAlert && mounted) {
        setState(() => showAlert = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAlertDialog();
        });
      }
    } catch (e) {
      if (kDebugMode) print('ERROR loading complaint progress: $e');
      setState(() {
        complaintSummaries = [];
        complaintProgress = 0.0;
        complaintStatusLabel = 'Error';
        complaintStatusDescription = '';
        complaintRawStatus = '';
        complaintDamageCategory = '';
      });
    }
  }


  // Load weather data
  Future<void> _loadWeather() async {
    setState(() {
      isLoadingWeather = true;
      weatherError = '';
    });

    try {
      final weatherService = WeatherService();

      // Get weather by city (Johor Bahru)
      final weather = await weatherService.getWeatherByCity('Johor Bahru');

      setState(() {
        weatherData = weather;
        isLoadingWeather = false;
      });
    } catch (e) {
      setState(() {
        weatherError = 'Failed to load weather';
        isLoadingWeather = false;
      });
      if (kDebugMode) print('Weather error: $e');
    }
  }

  // Fetch data from Firestore
  Future<void> fetchStudentData() async {
    setState(() {
      isLoadingStudent = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception("Not logged in");
      }
        final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        final doc = await FirebaseFirestore.instance
          .collection('student')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (doc.docs.isNotEmpty) {
        final data = doc.docs.first.data();
        setState(() {
          studentName = (data['studentName'] ?? '').toString();
          matricNo = (data['matricNo'] ?? '').toString();
          isLoadingStudent = false;
        });
        if (kDebugMode) {
          print('Firestore studentName=${studentName}, matricNo=${matricNo}');
        }
      } else {
        setState(() {
          studentName = 'Unknown';
          matricNo = '';
          isLoadingStudent = false;
        });
        if (kDebugMode) print('Student document not found');
      }
    } catch (e) {
      setState(() {
        studentName = 'Error loading';
        matricNo = '';
        isLoadingStudent = false;
      });
      if (kDebugMode) print('Error fetching student data: $e');
    }
  }

  void _showAlertDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning,
                    color: Colors.orange.shade700,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reminder: Technicians will be visiting for repairs today. Please keep the area clear and be cautious.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Get weather icon based on condition
  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
      case 'drizzle':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      default:
        return Icons.wb_cloudy;
    }
  }

  // Get weather color based on condition
  List<Color> _getWeatherColors(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return [Colors.orange.shade300, Colors.yellow.shade300];
      case 'clouds':
        return [Colors.grey.shade400, Colors.blueGrey.shade300];
      case 'rain':
      case 'drizzle':
        return [Colors.blue.shade400, Colors.indigo.shade300];
      case 'thunderstorm':
        return [Colors.purple.shade400, Colors.deepPurple.shade300];
      default:
        return [Colors.teal.shade300, Colors.blue.shade300];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.person, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            isLoadingStudent
                                ? 'Loading...'
                                : (studentName.isNotEmpty ? studentName : 'Guest'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isLoadingStudent && matricNo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              matricNo,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationPage(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.notifications, color: Colors.deepPurple),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () {
                          FirebaseAuth.instance.signOut();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status bars moved here so they scroll with the page
                    if (complaintSummaries.isNotEmpty) ...[
                      ...complaintSummaries.map((c) => _buildStatusBarFor(c)),
                      const SizedBox(height: 12),
                    ],

                    // Donate Card
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TipsPage()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.deepPurple, Colors.purple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Make a Donation',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Donate Now',
                                    style: TextStyle(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.volunteer_activism,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // DYNAMIC WEATHER CARD
                    GestureDetector(
                      onTap: _loadWeather, // Tap to refresh
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: weatherData != null
                                ? _getWeatherColors(weatherData!.mainCondition)
                                : [Colors.teal.shade300, Colors.blue.shade300],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: isLoadingWeather
                            ? Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              const SizedBox(height: 8),
                              Text(
                                'Loading weather...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                            : weatherError.isNotEmpty
                            ? Column(
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              weatherError,
                              style: TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              onPressed: _loadWeather,
                              child: Text(
                                'Retry',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        )
                            : weatherData != null
                            ? Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _getWeatherIcon(weatherData!.mainCondition),
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${weatherData!.temperature.round()}°',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    weatherData!.mainCondition.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    weatherData!.cityName,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Humidity: ${weatherData!.humidity}%',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Wind: ${weatherData!.windSpeed.toStringAsFixed(1)} m/s',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Weather description
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to\nrefresh',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                            : const SizedBox(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Schedule",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        InkWell(
                          onTap: complaintSummaries.any((c) => c.rawStatus == 'assigned') ? _showAlertDialog : null,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: complaintSummaries.any((c) => c.rawStatus == 'assigned') ? Colors.deepPurple : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    ScheduleItem(
                      icon: Icons.weekend,
                      iconColor: Colors.pink,
                      title: 'Furniture reparation',
                      subtitle: 'Level 1',
                      time: '10:00 AM',
                    ),
                    const SizedBox(height: 12),
                    ScheduleItem(
                      icon: Icons.electrical_services,
                      iconColor: Colors.deepPurple,
                      title: 'Electrical maintenance',
                      subtitle: 'Level 5',
                      time: '02:00 PM',
                    ),
                    const SizedBox(height: 12),
                    ScheduleItem(
                      icon: Icons.local_laundry_service,
                      iconColor: Colors.orange,
                      title: 'Washing machine reparation',
                      subtitle: 'Lobby',
                      time: '02:00 PM',
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ComplaintFormScreen(),
            ),
          );
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.home, color: Colors.deepPurple),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.calendar_today, color: Colors.grey),
              onPressed: () {},
            ),
            const SizedBox(width: 40),
            IconButton(
              icon: Icon(Icons.description, color: Colors.grey),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ActivityScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.settings, color: Colors.grey),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class ScheduleItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  const ScheduleItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}