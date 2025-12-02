import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'calendar.dart';
import 'profile.dart';
import 'taskDetail.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple, fontFamily: 'Poppins'),
      home: const TechnicianDashboard(),
    );
  }
}

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  int selectedTab = 0;
  int selectedNavIndex = 0;
  String? currentUserId;
  String? technicianDocId; // The actual technician document ID
  String technicianName = 'Technician';

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _fetchTechnicianDocId();
    
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          currentUserId = user?.uid;
        });
        if (user != null) {
          _fetchTechnicianDocId();
        }
      }
    });
  }

  // Fetch the technician's document ID from the technician collection
  Future<void> _fetchTechnicianDocId() async {
    try {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email == null) return;
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('technician')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        print('Technician Doc ID: $docId');
        final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        final fetchedName = (data['name'] ?? data['fullName'] ?? data['technicianName'])?.toString();
        final displayFallback = FirebaseAuth.instance.currentUser?.displayName ?? 'Technician';
        if (mounted) {
          setState(() {
            technicianDocId = docId;
            technicianName = fetchedName ?? displayFallback;
          });
        }
      }
    } catch (e) {
      print('Error fetching technician doc ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF4CAF50)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.engineering,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hello!',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      Text(
                        technicianName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress Card - Dynamic based on today's completed tasks
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaint')
                    .where('assignedTo', isEqualTo: '/collection/technician/$technicianDocId')
                    .snapshots(),
                builder: (context, snapshot) {
                  int totalToday = 0;
                  int completedToday = 0;
                  if (snapshot.hasData) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final validStatuses = ['approved', 'ongoing', 'complete', 'completed'];
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = (data['reportStatus'] ?? '').toString().toLowerCase();
                      if (!validStatuses.contains(status)) continue;
                      Timestamp? scheduledTs;
                      if (data['scheduledDate'] != null && data['scheduledDate'] is Timestamp) {
                        scheduledTs = data['scheduledDate'] as Timestamp;
                      }
                      if (scheduledTs != null) {
                        final scheduled = scheduledTs.toDate().toUtc().add(const Duration(hours: 8));
                        final sd = DateTime(scheduled.year, scheduled.month, scheduled.day);
                        if (sd == today) {
                          totalToday++;
                          if (status == 'complete' || status == 'completed') {
                            completedToday++;
                          }
                        }
                      }
                    }
                  }
                  final percentage = totalToday == 0 ? 0 : ((completedToday / totalToday) * 100).toInt();
                  String progressMessage = "Come on, you got things to do!";
                  if (percentage > 50 && percentage < 100) {
                    progressMessage = "Your today's task almost done!";
                  } else if (percentage == 100 && totalToday > 0) {
                    progressMessage = "Well done! You have completed all tasks!";
                  }
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF5A52E8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    progressMessage,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$completedToday/$totalToday',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: CircularProgressIndicator(
                                    value: totalToday == 0 ? 0 : completedToday / totalToday,
                                    strokeWidth: 8,
                                    backgroundColor: Colors.white.withOpacity(0.3),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                Text(
                                  '$percentage%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6C63FF),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('View Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Tabs: Today's tasks / Approved / Ongoing / Completed
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTab("Today's tasks", 0),
                    const SizedBox(width: 8),
                    _buildTab('Approved', 1),
                    const SizedBox(width: 8),
                    _buildTab('Ongoing', 2),
                    const SizedBox(width: 8),
                    _buildTab('Completed', 3),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Tasks List Section
            Expanded(
              child: technicianDocId == null 
              ? const Center(child: Text("Loading technician info..."))
              : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaint')
                    .where('assignedTo', isEqualTo: '/collection/technician/$technicianDocId')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    print('Query Error: ${snapshot.error}');
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    print('No tasks found for technician: $technicianDocId');
                    return const Center(child: Text('No tasks assigned to you.'));
                  }

                  final rawTasks = snapshot.data!.docs;
                  print('Found ${rawTasks.length} tasks for technician: $technicianDocId');

                  // Normalize tasks with metadata
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);

                  List<Map<String, dynamic>> normalized = rawTasks.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? scheduled;
                    if (data['scheduledDate'] != null && data['scheduledDate'] is Timestamp) {
                      // Convert stored timestamp to UTC then apply UTC+8 (Malaysia timezone)
                      scheduled = (data['scheduledDate'] as Timestamp).toDate().toUtc().add(const Duration(hours: 8));
                    }
                    DateTime? reported;
                    if (data['reportedDate'] != null && data['reportedDate'] is Timestamp) {
                      reported = (data['reportedDate'] as Timestamp).toDate().toUtc().add(const Duration(hours: 8));
                    }
                    final status = (data['reportStatus'] ?? '').toString();
                    return {
                      'id': doc.id,
                      'data': data,
                      'scheduled': scheduled,
                      'reported': reported,
                      'status': status,
                    };
                  }).toList();

                  // Filter by valid statuses: Approved, Ongoing, Completed
                  final validStatuses = ['approved', 'ongoing', 'complete', 'completed'];
                  final validTasks = normalized.where((t) {
                    final status = (t['status'] ?? '').toString().toLowerCase();
                    return validStatuses.contains(status);
                  }).toList();

                  // Apply tab filters
                  List<Map<String, dynamic>> filtered;
                  if (selectedTab == 0) {
                    // Today's tasks: scheduledDate is today AND valid status
                    filtered = validTasks.where((t) {
                      final s = t['scheduled'] as DateTime?;
                      if (s == null) return false;
                      final sd = DateTime(s.year, s.month, s.day);
                      return sd == today;
                    }).toList();
                  } else if (selectedTab == 1) {
                    // Approved
                    filtered = validTasks.where((t) {
                      final status = (t['status'] ?? '').toString().toLowerCase();
                      return status == 'approved';
                    }).toList();
                    } else if (selectedTab == 2) {
                      // Ongoing
                      filtered = validTasks.where((t) {
                        final status = (t['status'] ?? '').toString().toLowerCase();
                        return status == 'ongoing';
                      }).toList();
                    } else {
                      // Completed
                    filtered = validTasks.where((t) {
                      final status = (t['status'] ?? '').toString().toLowerCase();
                        return status == 'complete' || status == 'completed';
                    }).toList();
                  }

                  // Sort: pending and most recent at top, completed at bottom for Today's view
                  filtered.sort((a, b) {
                    final aStatus = (a['status'] ?? '').toString().toLowerCase();
                    final bStatus = (b['status'] ?? '').toString().toLowerCase();

                    if (selectedTab == 0) {
                      // For today's tasks, put pending before completed
                      if (aStatus == bStatus) {
                        final aDate = (a['reported'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
                        final bDate = (b['reported'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
                        return bDate.compareTo(aDate); // most recent first
                      }
                      if (aStatus == 'pending') return -1;
                      if (bStatus == 'pending') return 1;
                      return aStatus.compareTo(bStatus);
                    }

                    // For other tabs, sort by reported date desc
                    final aDate = (a['reported'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bDate = (b['reported'] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bDate.compareTo(aDate);
                  });

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No tasks match the selected filter.'));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final t = filtered[index];
                      final task = t['data'] as Map<String, dynamic>;

                      // Use scheduledDate for display (fallback to reported)
                      String dateStr = '--/--/----';
                      String timeStr = '--:--';
                      final scheduled = t['scheduled'] as DateTime?;
                      final reported = t['reported'] as DateTime?;
                      DateTime? displayDate = scheduled ?? reported;
                      if (displayDate != null) {
                        dateStr = '${displayDate.year}-${displayDate.month.toString().padLeft(2,'0')}-${displayDate.day.toString().padLeft(2,'0')}';
                        final hour = displayDate.hour % 12 == 0 ? 12 : displayDate.hour % 12;
                        final minute = displayDate.minute.toString().padLeft(2, '0');
                        final ampm = displayDate.hour < 12 ? 'AM' : 'PM';
                        timeStr = '$hour:$minute $ampm';
                      }

                      // Combine date and time for display in the card (user requested both)
                      final scheduledDisplay = dateStr != '--/--/----' ? '$dateStr  $timeStr' : timeStr;

                      final imageUrl = (task['damagePic'] != null && task['damagePic'] is String) ? task['damagePic'] as String : null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
                        child: _buildTaskCard(
                          task['complaintID'] ?? t['id'] ?? 'unknown',
                          task['inventoryDamage'] ?? 'No title',
                          task['roomEntryConsent'] == true ? 'Room Entry Allowed' : 'Wait for student',
                          dateStr,
                          Colors.pink.shade50,
                          Icons.inbox_rounded,
                          Colors.pink,
                          task['reportStatus'] ?? 'Unknown',
                          imageUrl: imageUrl,
                          scheduledTime: scheduledDisplay,
                          statusColor: _getStatusColor(task['reportStatus'] ?? 'Unknown'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 80,
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

  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'approved') {
      return Colors.purple; // Purple for Approved
    } else if (lowerStatus == 'ongoing') {
      return Colors.blue; // Blue for Ongoing
    } else if (lowerStatus == 'complete' || lowerStatus == 'completed') {
      return Colors.green; // Green for Completed
    }
    return Colors.grey; // Default fallback
  }

  Widget _buildTab(String title, int index) {
    final isSelected = selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6C63FF),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    String id,
    String title,
    String location,
    String time,
    Color bgColor,
    IconData icon,
    Color iconColor,
    String status,
    {String? imageUrl, String? scheduledTime, Color? statusColor}
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailPage(
              taskId: id,
              title: title,
              location: location,
              time: scheduledTime ?? time,
              status: status,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(icon, color: iconColor, size: 24),
                      )
                    : Icon(icon, color: iconColor, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: const TextStyle(fontSize: 13, color: Colors.black45),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor?.withOpacity(0.2) ?? Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor ?? Colors.amber,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          scheduledTime ?? time,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // FIXED NAVIGATION - Uses pushReplacement for smooth switching
  Widget _buildNavIcon(IconData icon, int index) {
    final isSelected = selectedNavIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (index == selectedNavIndex) return; // Already on this page
        
        setState(() {
          selectedNavIndex = index;
        });

        if (index == 1) {
          // Navigate to Calendar
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CalendarPage()),
          );
        } else if (index == 2) {
          // Navigate to Profile
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
}
