import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int selectedNavIndex = 1;
  DateTime selectedDate = DateTime.now();
  double timeSlotHeight = 120.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(7 * timeSlotHeight);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Fetch tasks for the selected day
  Stream<QuerySnapshot> getTaskStream() {
    return FirebaseFirestore.instance
        .collection('technician')
        .doc('technicianId') // change if needed
        .collection('tasks')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EFF5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildWeekRow(),
            const SizedBox(height: 10),
            _buildOngoingHeader(),
            Expanded(
              child: Container(
                color: const Color(0xFFFFFDF5),
                child: GestureDetector(
                  onScaleUpdate: (details) {
                    setState(() {
                      double newHeight = timeSlotHeight * details.scale;
                      if (newHeight >= 80 && newHeight <= 200) {
                        timeSlotHeight = newHeight;
                      }
                    });
                  },
                  child: StreamBuilder<QuerySnapshot>(
                    stream: getTaskStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No tasks found"));
                      }

                      // Filter by date
                      final allTasks = snapshot.data!.docs;
                      final dayTasks = allTasks.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['scheduleDate'] == null) return false;
                        final taskDate =
                        (data['scheduleDate'] as Timestamp).toDate();
                        return taskDate.year == selectedDate.year &&
                            taskDate.month == selectedDate.month &&
                            taskDate.day == selectedDate.day;
                      }).toList();

                      // Single scrollable area so times, grid lines and events stay aligned
                      return SingleChildScrollView(
                        controller: _scrollController,
                        child: SizedBox(
                          height: 24 * timeSlotHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTimeColumn(),
                              Expanded(
                                child: Stack(
                                  children: [
                                    _buildGridLines(),
                                    _buildEvents(dayTasks),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // =============================== UI SECTIONS ==============================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Text(
            'Calendar',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A3A3A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedDate = selectedDate.subtract(const Duration(days: 30));
                  });
                },
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                color: Colors.grey,
              ),
              Text(
                "${_monthName(selectedDate.month)} ${selectedDate.year}",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A3A3A),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedDate = selectedDate.add(const Duration(days: 30));
                  });
                },
                icon: const Icon(Icons.arrow_forward_ios, size: 20),
                color: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekRow() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final weekDays = List.generate(
      7,
          (i) => startOfWeek.add(Duration(days: i)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: weekDays.length,
          itemBuilder: (context, i) {
            final day = weekDays[i];
            final isSelected = day.day == selectedDate.day &&
                day.month == selectedDate.month;
            return GestureDetector(
              onTap: () {
                setState(() => selectedDate = day);
              },
              child: _buildDayCard(day, isSelected),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOngoingHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: const Text(
        'Ongoing',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTimeColumn() {
    return SizedBox(
      width: 70,
      child: Column(
        children: List.generate(24, (index) {
          return SizedBox(
            height: timeSlotHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, top: 8),
                child: Text(
                  '${index % 12 == 0 ? 12 : index % 12}${index < 12 ? 'AM' : 'PM'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGridLines() {
    return Column(
      children: List.generate(24, (index) {
        return Container(
          height: timeSlotHeight,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEvents(List<QueryDocumentSnapshot> tasks) {
    return SizedBox(
      height: 24 * timeSlotHeight,
      child: Stack(
        children: tasks.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final start = (data['scheduleDate'] as Timestamp).toDate();
          final duration = (data['duration'] ?? 1.0).toDouble();
          final color = _parseColor(data['color'] ?? "#FFA726");

          return _buildEventCard(
            data['complaint'] ?? 'No Title',
            data['location'] ?? 'Unknown',
            start,
            duration,
            color,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventCard(
      String title,
      String location,
      DateTime start,
      double duration,
      Color color,
      ) {
    double topPosition = start.hour * timeSlotHeight +
        (start.minute / 60.0) * timeSlotHeight;
    double height = duration * timeSlotHeight - 10;

    String endTime = TimeOfDay(
        hour: (start.hour + duration).floor(),
        minute: ((start.minute + (duration * 60) % 60)).round())
        .format(context);

    return Positioned(
      top: topPosition,
      left: 10,
      right: 10,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '${_formatTime(start)} - $endTime',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(DateTime day, bool isSelected) {
    return Container(
      width: 90,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4FC3C3) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.day.toString(),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey.shade400,
            ),
          ),
          Text(
            ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day.weekday % 7],
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? Colors.white : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
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
    );
  }

  Widget _buildNavIcon(IconData icon, int index) {
    final isSelected = selectedNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => selectedNavIndex = index);
        if (index == 0) Navigator.pop(context);
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

  // =============================== HELPERS ==============================

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final amPm = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $amPm';
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }
}