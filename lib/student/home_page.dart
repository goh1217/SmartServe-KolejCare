import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:owtest/student/complaint_form_screen.dart';
import 'services/weatherService.dart';

import 'notification_page.dart';
import 'donate_page.dart';
import 'screens/activity.dart';

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

  Future<void> _loadComplaintProgress() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (kDebugMode) print('Loading complaint progress for user email: $email');

    if (email == null || email.isEmpty) {
      if (kDebugMode) print('No user logged in');
      setState(() {
        complaintProgress = 0.0;
        complaintStatusLabel = 'No reports';
        complaintStatusDescription = '';
      });
      return;
    }

    final studentQuery = await FirebaseFirestore.instance
        .collection('student')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (studentQuery.docs.isEmpty) {
      if (kDebugMode) print('No student document found for $email');
      setState(() {
        complaintProgress = 0.0;
        complaintStatusLabel = 'No reports';
        complaintStatusDescription = '';
      });
      return;
    }

    final studentData = studentQuery.docs.first.data();
    if (kDebugMode) print('Student data: $studentData');

    // Look for common complaint id fields inside student document
    String complaintIdRaw = (studentData['complaintID'] ?? studentData['complaintId'] ?? studentData['complaint'] ?? studentData['latestComplaintId'] ?? studentData['latestComplaint'] ?? '').toString();
    String? complaintId = complaintIdRaw.isNotEmpty ? complaintIdRaw : null;

    if (kDebugMode) print('Found complaintId in student doc: $complaintId');

    if (complaintId == null) {
      // No linked complaint id found
      setState(() {
        complaintProgress = 0.0;
        complaintStatusLabel = 'No reports';
        complaintStatusDescription = '';
      });
      return;
    }

    // Fetch the complaint document by its document id
    final complaintDoc = await FirebaseFirestore.instance.collection('complaint').doc(complaintId).get();
    if (!complaintDoc.exists) {
      if (kDebugMode) print('Complaint doc $complaintId not found');
      setState(() {
        complaintProgress = 0.0;
        complaintStatusLabel = 'No reports';
        complaintStatusDescription = '';
      });
      return;
    }

    final data = complaintDoc.data() ?? {};
    if (kDebugMode) print('Complaint data: $data');

    // Try different field names for damage/category
    final categoryRaw = (data['damageCategory'] ?? data['damage_category'] ?? data['category'] ?? data['damage'] ?? '').toString();
    final category = categoryRaw.isNotEmpty ? categoryRaw : '';

    // Try different field names for status
    final statusRaw = (data['status'] ?? data['reportStatus'] ?? data['Status'] ?? data['ReportStatus'] ?? '').toString();
    final status = statusRaw.trim();

    if (kDebugMode) print('Status found: "$status"');

    // Map status to progress and description
    double progress = 0.0;
    String desc = '';
    String displayText = '';
    
    final s = status.toLowerCase();
    
    if (s == 'submitted') {
      progress = 0.15;
      desc = 'Submitted';
      displayText = 'Report\nSubmitted';
    } else if (s == 'pending') {
      progress = 0.30;
      desc = 'Pending';
      displayText = 'Under\nReview';
    } else if (s == 'reviewed') {
      progress = 0.50;
      desc = 'Reviewed';
      displayText = 'Being\nReviewed';
    } else if (s.contains('approved') || s == 'approved') {
      progress = 0.70;
      desc = 'Approved';
      displayText = 'Report\nApproved';
    } else if (s == 'rejected') {
      progress = 0.70;
      desc = 'Rejected';
      displayText = 'Report\nRejected';
    } else if (s == 'assigned') {
      progress = 0.90;
      desc = 'Assigned';
      displayText = 'Technician\nOn The Way';
    } else if (s == 'completed') {
      progress = 1.0;
      desc = 'Completed';
      displayText = 'Work\nCompleted';
    } else {
      // Fallback
      progress = 0.0;
      desc = status.isNotEmpty ? status : 'No reports';
      displayText = status.isNotEmpty ? status : 'No\nReports';
    }

    if (kDebugMode) print('Setting progress: $progress, label: $desc');

    setState(() {
      complaintProgress = progress;
      complaintStatusLabel = displayText;
      complaintRawStatus = s;
      complaintStatusDescription = '${(progress * 100).round()}%';
      complaintDamageCategory = category;
    });

    // Show alert only when status is 'assigned' and we haven't shown it yet
    if (s == 'assigned' && showAlert && mounted) {
      // prevent multiple displays
      setState(() {
        showAlert = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAlertDialog();
      });
    }
  } catch (e) {
    if (kDebugMode) print('ERROR loading complaint progress: $e');
    setState(() {
      complaintProgress = 0.0;
      complaintStatusLabel = 'Error';
      complaintStatusDescription = '';
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
      final doc = await FirebaseFirestore.instance
          .collection('student')
          .where('email', isEqualTo: user.email)
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
            // Show status bar only when there is a linked complaint (status or category available)
            (complaintRawStatus.isNotEmpty || complaintDamageCategory.isNotEmpty)
                ? Column(
                    children: [
                      _buildStatusBar(),
                      const SizedBox(height: 12),
                    ],
                  )
                : const SizedBox.shrink(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          onTap: complaintRawStatus == 'assigned' ? _showAlertDialog : null,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: complaintRawStatus == 'assigned' ? Colors.deepPurple : Colors.grey,
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