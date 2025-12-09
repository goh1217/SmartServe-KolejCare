import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

// ============================================================================
// HELPER CLASSES FOR TIME SLOT MANAGEMENT
// ============================================================================

/// Represents a single time slot with availability status
class TimeSlot {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isAvailable;
  final String? taskTitle;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    this.taskTitle,
  });

  String get displayTime {
    return '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Represents a technician's existing booking
class TechnicianBooking {
  final DateTime scheduleDate;
  final int estimatedDurationJobDone;
  final String? taskTitle;

  TechnicianBooking({
    required this.scheduleDate,
    required this.estimatedDurationJobDone,
    this.taskTitle,
  });

  DateTime get endDateTime {
    return scheduleDate.add(Duration(hours: estimatedDurationJobDone));
  }

  bool overlaps(DateTime start, DateTime end) {
    return (start.isBefore(endDateTime) && end.isAfter(scheduleDate));
  }
}

// ============================================================================
// TIME SLOT CALCULATOR
// ============================================================================

class TimeSlotCalculator {
  static const int workStartHour = 8;
  static const int workEndHour = 18;
  static const int slotDurationMinutes = 60;

  static List<TimeSlot> generateTimeSlots({
    required DateTime selectedDate,
    required List<TechnicianBooking> existingBookings,
    int durationNeeded = 1,
  }) {
    final List<TimeSlot> slots = [];

    final dayBookings = existingBookings.where((booking) {
      return isSameDay(booking.scheduleDate, selectedDate);
    }).toList();

    DateTime currentSlotStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      workStartHour,
    );

    final workEndTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      workEndHour,
    );

    while (currentSlotStart.add(Duration(hours: durationNeeded)).isBefore(workEndTime) ||
        currentSlotStart.add(Duration(hours: durationNeeded)).isAtSameMomentAs(workEndTime)) {

      final slotEnd = currentSlotStart.add(Duration(hours: durationNeeded));

      bool isAvailable = true;
      String? blockingTask;

      for (var booking in dayBookings) {
        if (booking.overlaps(currentSlotStart, slotEnd)) {
          isAvailable = false;
          blockingTask = booking.taskTitle;
          break;
        }
      }

      final now = DateTime.now();
      final isPastSlot = currentSlotStart.isBefore(now);

      if (!isPastSlot) {
        slots.add(TimeSlot(
          startTime: TimeOfDay(
            hour: currentSlotStart.hour,
            minute: currentSlotStart.minute,
          ),
          endTime: TimeOfDay(
            hour: slotEnd.hour,
            minute: slotEnd.minute,
          ),
          isAvailable: isAvailable,
          taskTitle: blockingTask,
        ));
      }

      currentSlotStart = currentSlotStart.add(const Duration(minutes: slotDurationMinutes));
    }

    return slots;
  }

  static bool hasBookingsOnDate(DateTime date, List<TechnicianBooking> bookings) {
    return bookings.any((booking) => isSameDay(booking.scheduleDate, date));
  }

  static bool isFullyBooked(DateTime date, List<TechnicianBooking> bookings) {
    final slots = generateTimeSlots(selectedDate: date, existingBookings: bookings);
    return slots.isNotEmpty && slots.every((slot) => !slot.isAvailable);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ============================================================================
// MAIN WIDGET
// ============================================================================

class AssignTechnicianPage extends StatefulWidget {
  final String complaintId;
  final dynamic complaint;

  const AssignTechnicianPage({
    Key? key,
    required this.complaintId,
    required this.complaint,
  }) : super(key: key);

  @override
  State<AssignTechnicianPage> createState() => _AssignTechnicianPageState();
}

class _AssignTechnicianPageState extends State<AssignTechnicianPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _durationController = TextEditingController();

  String? selectedTechnicianId;
  Map<String, dynamic>? selectedTechnicianData;
  bool isAssigning = false;
  Map<String, dynamic>? recommendedTechnicianData;
  bool isManualSelection = false;

  // Scheduling fields
  DateTime? selectedScheduleDateTime;
  int? selectedEstimatedDurationHours;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  TimeOfDay? _selectedTime;

  // NEW: Time slot management
  List<TechnicianBooking> technicianBookings = [];
  List<TimeSlot> availableTimeSlots = [];
  TimeSlot? selectedTimeSlot;

  // Booked dates for selected technician
  Set<DateTime> bookedDates = {};
  bool isLoadingBookedDates = false;

  // Rejection fields
  final _rejectionReasonController = TextEditingController();
  bool _isRejecting = false;

  @override
  void initState() {
    super.initState();
    _getRecommendedTechnician();
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    _durationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getRecommendedTechnician() async {
    final technicians = await getAvailableTechniciansStream().first;
    if (technicians.isNotEmpty) {
      setState(() {
        recommendedTechnicianData = technicians.first;
        selectedTechnicianId = recommendedTechnicianData!['id'];
        selectedTechnicianData = recommendedTechnicianData;
      });
      await _loadBookedDates(selectedTechnicianId!);
    }
  }

  // MODIFIED: Load technician bookings with full details
  Future<void> _loadBookedDates(String technicianId) async {
    setState(() {
      isLoadingBookedDates = true;
    });

    try {
      final assignedPath = '/collection/technician/$technicianId';
      final snap = await _firestore
          .collection('complaint')
          .where('assignedTo', isEqualTo: assignedPath)
          .where('reportStatus', whereIn: ['Approved', 'In Progress'])
          .get();

      final Set<DateTime> dates = {};
      final List<TechnicianBooking> bookings = [];

      for (var doc in snap.docs) {
        final data = doc.data();
        final sd = data['scheduleDate'];
        if (sd is Timestamp) {
          final scheduleDateTime = sd.toDate();
          final duration = data['estimatedDurationJobDone'] as int? ?? 1;
          final title = data['title'] ?? data['inventoryDamage'] ?? 'Task';

          dates.add(DateTime(scheduleDateTime.year, scheduleDateTime.month, scheduleDateTime.day));

          bookings.add(TechnicianBooking(
            scheduleDate: scheduleDateTime,
            estimatedDurationJobDone: duration,
            taskTitle: title,
          ));
        }
      }

      setState(() {
        bookedDates = dates;
        technicianBookings = bookings;
        isLoadingBookedDates = false;
      });
    } catch (e) {
      setState(() {
        isLoadingBookedDates = false;
      });
    }
  }

  Stream<List<Map<String, dynamic>>> getAvailableTechniciansStream() {
    String maintenanceField =
    _mapCategoryToMaintenanceField(widget.complaint.category);

    return _firestore
        .collection('technician')
        .where('availability', isEqualTo: true)
        .where('maintenanceField', isEqualTo: maintenanceField)
        .snapshots()
        .map((snapshot) {
      var technicians = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        data['tasksAssigned'] =
        data['tasksAssigned'] is List ? data['tasksAssigned'] : [];
        return data;
      }).toList();

      technicians.sort((a, b) {
        int tasksA = (a['tasksAssigned'] as List).length;
        int tasksB = (b['tasksAssigned'] as List).length;
        return tasksA.compareTo(tasksB);
      });

      return technicians;
    });
  }

  String _mapCategoryToMaintenanceField(String category) {
    switch (category.toLowerCase()) {
      case 'electrical':
      case 'electricity':
        return 'Electrical';
      case 'plumbing':
      case 'water':
        return 'Plumbing';
      case 'furniture':
      case 'carpentry':
        return 'Furniture';
      case 'air conditioning':
      case 'ac':
      case 'hvac':
        return 'HVAC';
      default:
        return category;
    }
  }

  Future<void> assignTechnician() async {
    if (selectedTechnicianId == null || selectedTechnicianData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a technician'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedScheduleDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a schedule date and time slot'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedEstimatedDurationHours == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter estimated duration'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isAssigning = true;
    });

    try {
      DocumentReference complaintRef =
      _firestore.collection('complaint').doc(widget.complaintId);

      final currentUser = FirebaseAuth.instance.currentUser;
      final String reviewedByPath =
      currentUser != null ? '/collection/staff/${currentUser.uid}' : '';

      await complaintRef.update({
        'reportStatus': 'Approved',
        'assignedTo': '/collection/technician/$selectedTechnicianId',
        'assignedDate': FieldValue.serverTimestamp(),
        'scheduleDate': Timestamp.fromDate(selectedScheduleDateTime!),
        'estimatedDurationJobDone': selectedEstimatedDurationHours,
        'isRead': false,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'reviewedBy': reviewedByPath,
        'reviewedOn': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('technician')
          .doc(selectedTechnicianId)
          .update({
        'tasksAssigned': FieldValue.arrayUnion([complaintRef]),
      });

      setState(() {
        isAssigning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assigned ${selectedTechnicianData!['technicianName']} successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        isAssigning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning technician: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectComplaint(String reason) async {
    if (reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a reason for rejection.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRejecting = true;
    });

    try {
      String reviewedByName = '';
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final docById =
          await _firestore.collection('staff').doc(user.uid).get();
          if (docById.exists) {
            final d = docById.data();
            reviewedByName = (d?['staffName'] ??
                d?['name'] ??
                d?['displayName'] ??
                '')
                .toString();
          }

          if (reviewedByName.isEmpty) {
            final q = await _firestore
                .collection('staff')
                .where('authUid', isEqualTo: user.uid)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              final d = q.docs.first.data();
              reviewedByName = (d['staffName'] ??
                  d['name'] ??
                  d['displayName'] ??
                  '')
                  .toString();
            }
          }

          if (reviewedByName.isEmpty && (user.email ?? '').isNotEmpty) {
            final q2 = await _firestore
                .collection('staff')
                .where('email', isEqualTo: user.email)
                .limit(1)
                .get();
            if (q2.docs.isNotEmpty) {
              final d = q2.docs.first.data();
              reviewedByName = (d['staffName'] ??
                  d['name'] ??
                  d['displayName'] ??
                  '')
                  .toString();
            }
          }

          if (reviewedByName.isEmpty) reviewedByName = user.uid;
        }
      } catch (_) {
        reviewedByName = '';
      }

      await _firestore.collection('complaint').doc(widget.complaintId).update({
        'reportStatus': 'Rejected',
        'rejectionReason': reason,
        'isRead': false,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'reviewedBy': reviewedByName,
        'reviewedOn': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint rejected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting complaint: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRejecting = false;
        });
      }
    }
  }

  void _showRejectDialog() {
    _rejectionReasonController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Complaint'),
          content: TextField(
            controller: _rejectionReasonController,
            decoration: const InputDecoration(
              hintText: 'Enter reason for rejection...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = _rejectionReasonController.text.trim();
                Navigator.pop(context);
                _rejectComplaint(reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Reject'),
            ),
          ],
        );
      },
    );
  }

  void _scrollToCalendar() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  void _scrollToTimeSlots() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  void _scrollToDuration() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Technician'),
        backgroundColor: const Color(0xFF7C3AED),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildComplaintDetailsCard(),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: getAvailableTechniciansStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    recommendedTechnicianData == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final technicians = snapshot.data ?? [];

                if (technicians.isEmpty) {
                  return _buildNoTechniciansFound();
                }

                return isManualSelection
                    ? _buildManualSelectionView(technicians)
                    : _buildRecommendationView(technicians);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationView(List<Map<String, dynamic>> technicians) {
    if (recommendedTechnicianData == null) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggested Technician',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          _buildTechnicianCard(recommendedTechnicianData!, true,
              isRecommendation: true),
          const SizedBox(height: 16),
          if (selectedTechnicianId != null) ...[
            _buildSchedulingSection(),
            const SizedBox(height: 16),
          ],
          _buildRecommendationButtons(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildManualSelectionView(List<Map<String, dynamic>> technicians) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('Available Technicians',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _mapCategoryToMaintenanceField(
                              widget.complaint.category),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: technicians.length,
                  itemBuilder: (context, index) {
                    final technician = technicians[index];
                    final isSelected =
                        selectedTechnicianId == technician['id'];
                    return _buildTechnicianCard(technician, isSelected);
                  },
                ),
                if (selectedTechnicianId != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSchedulingSection(),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
        _buildManualActionButtons(),
      ],
    );
  }

  Widget _buildSchedulingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: Color(0xFF7C3AED), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Schedule Assignment',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoadingBookedDates)
            const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                ))
          else ...[
            _buildCalendar(),
            _buildCalendarLegend(),
          ],
          const SizedBox(height: 16),
          if (_selectedDay != null) ...[
            const Divider(),
            const SizedBox(height: 16),
            _buildTimeSlotSelector(),
            const SizedBox(height: 16),
            if (selectedTimeSlot != null) _buildDurationInput(),
          ],
        ],
      ),
    );
  }

  // MODIFIED: Calendar with partial booking indicators
  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.now(),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      enabledDayPredicate: (day) {
        // Allow all future dates
        return !day.isBefore(DateTime.now().subtract(const Duration(days: 1)));
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
          selectedTimeSlot = null;
          selectedScheduleDateTime = null;
          selectedEstimatedDurationHours = null;
          _durationController.clear();

          // Generate available time slots
          availableTimeSlots = TimeSlotCalculator.generateTimeSlots(
            selectedDate: selectedDay,
            existingBookings: technicianBookings,
            durationNeeded: 1,
          );
        });
        _scrollToTimeSlots();
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          return _buildCalendarDay(day, false, false);
        },
        selectedBuilder: (context, day, focusedDay) {
          return _buildCalendarDay(day, true, false);
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildCalendarDay(day, false, true);
        },
      ),
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
        markerDecoration: BoxDecoration(),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      calendarFormat: CalendarFormat.month,
    );
  }

  // NEW: Custom calendar day builder
  Widget _buildCalendarDay(DateTime day, bool isSelected, bool isToday) {
    final hasBookings = TimeSlotCalculator.hasBookingsOnDate(day, technicianBookings);
    final isFullyBooked = TimeSlotCalculator.isFullyBooked(day, technicianBookings);

    Color backgroundColor;
    Color textColor = Colors.black;

    if (isSelected) {
      backgroundColor = const Color(0xFF7C3AED);
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = const Color(0xFF7C3AED).withOpacity(0.3);
    } else if (isFullyBooked) {
      backgroundColor = Colors.red.shade100;
      textColor = Colors.red.shade900;
    } else if (hasBookings) {
      backgroundColor = Colors.yellow.shade100;
    } else {
      backgroundColor = Colors.transparent;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (hasBookings && !isSelected)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isFullyBooked ? Colors.red : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // NEW: Calendar legend
  Widget _buildCalendarLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Available', Colors.white),
          _buildLegendItem('Partial', Colors.yellow.shade100),
          _buildLegendItem('Full', Colors.red.shade100),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  // NEW: Time slot selector (replaces time picker)
  Widget _buildTimeSlotSelector() {
    if (availableTimeSlots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Text(
          'No available time slots for this date',
          style: TextStyle(fontSize: 14, color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.access_time, color: Color(0xFF7C3AED), size: 20),
            SizedBox(width: 8),
            Text(
              'Select Available Time Slot',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: ListView.builder(
            itemCount: availableTimeSlots.length,
            itemBuilder: (context, index) {
              final slot = availableTimeSlots[index];
              return _buildTimeSlotCard(slot);
            },
          ),
        ),
      ],
    );
  }

  // NEW: Individual time slot card
  Widget _buildTimeSlotCard(TimeSlot slot) {
    final isSelected = selectedTimeSlot == slot;

    return GestureDetector(
      onTap: slot.isAvailable
          ? () {
        setState(() {
          selectedTimeSlot = slot;

          selectedScheduleDateTime = DateTime(
            _selectedDay!.year,
            _selectedDay!.month,
            _selectedDay!.day,
            slot.startTime.hour,
            slot.startTime.minute,
          );
        });
        _scrollToDuration();
      }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: !slot.isAvailable
              ? Colors.grey.shade100
              : isSelected
              ? const Color(0xFF7C3AED)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: !slot.isAvailable
                ? Colors.grey.shade300
                : isSelected
                ? const Color(0xFF7C3AED)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              slot.isAvailable ? Icons.access_time : Icons.block,
              color: !slot.isAvailable
                  ? Colors.grey
                  : isSelected
                  ? Colors.white
                  : const Color(0xFF7C3AED),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.displayTime,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: !slot.isAvailable
                          ? Colors.grey
                          : isSelected
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  if (!slot.isAvailable && slot.taskTitle != null)
                    Text(
                      'Booked: ${slot.taskTitle}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (slot.isAvailable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFFE8D9FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSelected ? 'Selected' : 'Available',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? const Color(0xFF7C3AED) : Colors.black87,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timer, color: Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Estimated Duration (hours)',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _durationController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter estimated hours',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) {
            final hours = int.tryParse(value);
            setState(() {
              selectedEstimatedDurationHours = hours;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRecommendationButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: isAssigning
                ? const SizedBox.shrink()
                : const Icon(Icons.check_circle),
            label: isAssigning
                ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Text('Accept & Assign',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: isAssigning ? null : assignTechnician,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              setState(() {
                isManualSelection = true;
                selectedTechnicianId = null;
                selectedTechnicianData = null;
                _selectedDay = null;
                _selectedTime = null;
                selectedScheduleDateTime = null;
                selectedEstimatedDurationHours = null;
                selectedTimeSlot = null;
                availableTimeSlots.clear();
                bookedDates.clear();
                technicianBookings.clear();
              });
            },
            child: const Text(
              'Choose Manually',
              style: TextStyle(
                  color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isRejecting ? null : _showRejectDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            child: _isRejecting
                ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Text('Reject Complaint',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildManualActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isAssigning ? null : assignTechnician,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: isAssigning
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Assign Selected Technician',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isRejecting ? null : _showRejectDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _isRejecting
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Reject Complaint',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintDetailsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Complaint Details',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          _buildDetailRow('Title', widget.complaint.title),
          _buildDetailRow('Category', widget.complaint.category),
          _buildDetailRow('Priority', widget.complaint.priority),
          _buildDetailRow('Student ID', widget.complaint.studentId),
          _buildDetailRow('Room', widget.complaint.room),
        ],
      ),
    );
  }

  Widget _buildNoTechniciansFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No available technicians found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            'for ${_mapCategoryToMaintenanceField(widget.complaint.category)} maintenance',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text('$label:',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianCard(Map<String, dynamic> technician, bool isSelected,
      {bool isRecommendation = false}) {
    return GestureDetector(
      onTap: isRecommendation
          ? null
          : () async {
        setState(() {
          selectedTechnicianId = technician['id'];
          selectedTechnicianData = technician;
          _selectedDay = null;
          _selectedTime = null;
          selectedScheduleDateTime = null;
          selectedEstimatedDurationHours = null;
          selectedTimeSlot = null;
          availableTimeSlots.clear();
          _durationController.clear();
        });
        await _loadBookedDates(technician['id']);
        _scrollToCalendar();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            else
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (!isRecommendation) ...[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSelected
                              ? const Color(0xFF7C3AED)
                              : Colors.grey[400]!,
                          width: 2),
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                ],
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
                  child: Text(
                    technician['technicianName']
                        ?.substring(0, 1)
                        .toUpperCase() ??
                        'T',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        technician['technicianName'] ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text('ID: ${technician['technicianNo'] ?? 'N/A'}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat(
                    Icons.build,
                    technician['maintenanceField'] ?? 'N/A',
                    Colors.grey[600]!),
                _buildStat(Icons.phone, technician['phoneNo'] ?? 'N/A',
                    Colors.grey[600]!),
                _buildStat(
                    Icons.assignment,
                    '${(technician['tasksAssigned'] as List).length} tasks',
                    Colors.grey[600]!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}