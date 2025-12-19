import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

// ============================================================================
// HELPER CLASSES FOR TIME SLOT MANAGEMENT
// ============================================================================

/// Represents a 30-minute time slot
class TimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final bool isAvailable;
  final String? taskTitle;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    this.taskTitle,
  });

  String get displayTime {
    final start = TimeOfDay.fromDateTime(startTime);
    final end = TimeOfDay.fromDateTime(endTime);
    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool overlaps(TimeSlot other) {
    return startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime);
  }
}

/// Represents a technician's existing booking
class TechnicianBooking {
  final List<DateTime> scheduledTimeSlots; // Array of timestamps
  final String? taskTitle;

  TechnicianBooking({
    required this.scheduledTimeSlots,
    this.taskTitle,
  });

  bool occupiesSlot(DateTime slotStart) {
    return scheduledTimeSlots.any((slot) {
      final diff = slot.difference(slotStart).inMinutes.abs();
      return diff < 30; // Same slot if within 30 minutes
    });
  }
}

// ============================================================================
// TIME SLOT CALCULATOR
// ============================================================================

class TimeSlotCalculator {
  static const int workStartHour = 8;
  static const int workEndHour = 18;
  static const int slotDurationMinutes = 30; // 30-minute slots

  /// Generate all 30-minute slots for a given day
  static List<TimeSlot> generateTimeSlots({
    required DateTime selectedDate,
    required List<TechnicianBooking> existingBookings,
  }) {
    final List<TimeSlot> slots = [];

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

    while (currentSlotStart.isBefore(workEndTime)) {
      final slotEnd = currentSlotStart.add(const Duration(minutes: slotDurationMinutes));

      // Check if this slot is occupied
      bool isAvailable = true;
      String? blockingTask;

      for (var booking in existingBookings) {
        if (booking.occupiesSlot(currentSlotStart)) {
          isAvailable = false;
          blockingTask = booking.taskTitle;
          break;
        }
      }

      // Don't show past slots
      final now = DateTime.now();
      if (currentSlotStart.isAfter(now)) {
        slots.add(TimeSlot(
          startTime: currentSlotStart,
          endTime: slotEnd,
          isAvailable: isAvailable,
          taskTitle: blockingTask,
        ));
      }

      currentSlotStart = slotEnd;
    }

    return slots;
  }

  /// Check if a date has enough continuous free slots for the duration
  static bool hasEnoughContinuousSlots(
      DateTime date,
      List<TechnicianBooking> bookings,
      int durationHours,
      ) {
    final slots = generateTimeSlots(selectedDate: date, existingBookings: bookings);
    final slotsNeeded = (durationHours * 60 / slotDurationMinutes).ceil();

    int maxContinuous = 0;
    int current = 0;

    for (var slot in slots) {
      if (slot.isAvailable) {
        current++;
        maxContinuous = maxContinuous > current ? maxContinuous : current;
      } else {
        current = 0;
      }
    }

    return maxContinuous >= slotsNeeded;
  }

  /// Calculate gaps in selected slots (in minutes)
  static List<Duration> calculateGaps(List<TimeSlot> selectedSlots) {
    if (selectedSlots.length <= 1) return [];

    final sorted = List<TimeSlot>.from(selectedSlots)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final gaps = <Duration>[];
    for (int i = 0; i < sorted.length - 1; i++) {
      final gap = sorted[i + 1].startTime.difference(sorted[i].endTime);
      if (gap.inMinutes > 0) {
        gaps.add(gap);
      }
    }

    return gaps;
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
  int? estimatedDurationHours;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Time slot management
  List<TechnicianBooking> technicianBookings = [];
  List<TimeSlot> availableTimeSlots = [];
  List<TimeSlot> selectedTimeSlots = [];
  int slotsNeeded = 0;

  // Available dates cache
  Set<DateTime> availableDates = {};
  Map<DateTime, String> datesStatus = {}; // 'green', 'yellow', or 'red'
  bool isLoadingDates = false;

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
      await _loadTechnicianBookings(selectedTechnicianId!);
      
      // Auto-scroll to duration input
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  /// Load technician's bookings for the month
  Future<void> _loadTechnicianBookings(String technicianId) async {
    setState(() {
      isLoadingDates = true;
    });

    try {
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final lastOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final assignedPath = '/collection/technician/$technicianId';
      
      // Query complaints assigned to this technician with scheduled time slots
      final snap = await _firestore
          .collection('complaint')
          .where('assignedTo', isEqualTo: assignedPath)
          .where('reportStatus', whereIn: ['Approved', 'In Progress'])
          .get();

      final List<TechnicianBooking> bookings = [];

      for (var doc in snap.docs) {
        final data = doc.data();
        final slots = data['scheduledDateTimeSlot'] as List<dynamic>?;

        if (slots != null && slots.isNotEmpty) {
          final timeSlots = slots
              .map((s) => (s as Timestamp).toDate().toLocal())
              .where((date) {
                // Only include slots within the current and next month
                return date.isAfter(firstOfMonth.subtract(const Duration(days: 1))) &&
                       date.isBefore(lastOfMonth.add(const Duration(days: 1)));
              })
              .toList();

          if (timeSlots.isNotEmpty) {
            bookings.add(TechnicianBooking(
              scheduledTimeSlots: timeSlots,
              taskTitle: data['title'] ?? data['inventoryDamage'] ?? 'Task',
            ));
          }
        }
      }

      setState(() {
        technicianBookings = bookings;
        isLoadingDates = false;
      });

      // Calculate available dates if duration is set
      if (estimatedDurationHours != null) {
        _calculateAvailableDates();
      }
    } catch (e) {
      setState(() {
        isLoadingDates = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bookings: $e')),
        );
      }
    }
  }

  /// Calculate which dates have enough continuous slots
  /// Also tracks dates with partial bookings (yellow) vs full availability (green)
  void _calculateAvailableDates() {
    if (estimatedDurationHours == null) return;

    final Set<DateTime> available = {};
    final Map<DateTime, String> status = {};
    final now = DateTime.now();

    for (int i = 0; i < 60; i++) {
      final date = now.add(Duration(days: i));
      final normalizedDate = DateTime(date.year, date.month, date.day);

      // Generate slots for this date
      final slots = TimeSlotCalculator.generateTimeSlots(
        selectedDate: normalizedDate,
        existingBookings: technicianBookings,
      );

      // Count available vs booked slots
      final totalSlots = slots.length;
      final availableSlots = slots.where((s) => s.isAvailable).length;
      final hasEnoughContinuous = TimeSlotCalculator.hasEnoughContinuousSlots(
        normalizedDate,
        technicianBookings,
        estimatedDurationHours!,
      );

      if (hasEnoughContinuous) {
        available.add(normalizedDate);
        
        // Determine color: green (all free), yellow (some bookings but still available)
        if (availableSlots == totalSlots) {
          status[normalizedDate] = 'green'; // Completely free
        } else {
          status[normalizedDate] = 'yellow'; // Has bookings but slots available
        }
      } else {
        // Red - no slots available or not enough continuous slots
        status[normalizedDate] = 'red';
      }
    }

    setState(() {
      availableDates = available;
      datesStatus = status;
    });
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

  /// Assign technician with transaction to prevent race conditions
  Future<void> assignTechnician() async {
    if (selectedTechnicianId == null || selectedTechnicianData == null) {
      _showError('Please select a technician');
      return;
    }

    if (selectedTimeSlots.isEmpty) {
      _showError('Please select time slots');
      return;
    }

    if (selectedTimeSlots.length < slotsNeeded) {
      _showError('Please select $slotsNeeded time slots (${slotsNeeded * 30} minutes)');
      return;
    }

    // Check for gaps and warn
    final gaps = TimeSlotCalculator.calculateGaps(selectedTimeSlots);
    if (gaps.any((gap) => gap.inMinutes > 30)) {
      final proceed = await _showGapWarning(gaps);
      if (!proceed) return;
    }

    setState(() {
      isAssigning = true;
    });

    try {
      // Use transaction to prevent race conditions
      await _firestore.runTransaction((transaction) async {
        final complaintRef = _firestore.collection('complaint').doc(widget.complaintId);
        final techRef = _firestore.collection('technician').doc(selectedTechnicianId);

        // Re-check if slots are still available
        final assignedPath = '/collection/technician/$selectedTechnicianId';
        final existingBookings = await _firestore
            .collection('complaint')
            .where('assignedTo', isEqualTo: assignedPath)
            .where('reportStatus', whereIn: ['Approved', 'In Progress'])
            .get();

        final currentBookings = <TechnicianBooking>[];
        for (var doc in existingBookings.docs) {
          final data = doc.data();
          final slots = data['scheduledDateTimeSlot'] as List<dynamic>?;
          if (slots != null) {
            currentBookings.add(TechnicianBooking(
              scheduledTimeSlots: slots.map((s) => (s as Timestamp).toDate()).toList(),
              taskTitle: data['title'],
            ));
          }
        }

        // Verify slots are still free
        for (var selectedSlot in selectedTimeSlots) {
          for (var booking in currentBookings) {
            if (booking.occupiesSlot(selectedSlot.startTime)) {
              throw Exception('Time slot ${selectedSlot.displayTime} was just booked by another admin!');
            }
          }
        }

        // All clear - proceed with booking
        final currentUser = FirebaseAuth.instance.currentUser;
        final reviewedByPath = currentUser != null ? '/collection/staff/${currentUser.uid}' : '';

        final timeSlotTimestamps = selectedTimeSlots
            .map((slot) => Timestamp.fromDate(slot.startTime.toUtc()))
            .toList();

        transaction.update(complaintRef, {
          'reportStatus': 'Approved',
          'assignedTo': assignedPath,
          'assignedDate': FieldValue.serverTimestamp(),
          'scheduledDateTimeSlot': timeSlotTimestamps,
          'estimatedDurationJobDone': estimatedDurationHours,
          'isRead': false,
          'lastStatusUpdate': FieldValue.serverTimestamp(),
          'reviewedBy': reviewedByPath,
          'reviewedOn': FieldValue.serverTimestamp(),
          'statusChangeCount': FieldValue.increment(1),
          'lastStatusChangedAt': FieldValue.serverTimestamp(),
          'assignmentNotificationRead': false,
        });

        transaction.update(techRef, {
          'tasksAssigned': FieldValue.arrayUnion([complaintRef]),
        });
      });

      setState(() {
        isAssigning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assigned ${selectedTechnicianData!['technicianName']} successfully!'),
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
            content: Text(e.toString().contains('was just booked')
                ? e.toString().replaceAll('Exception: ', '')
                : 'Error assigning technician: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<bool> _showGapWarning(List<Duration> gaps) async {
    final maxGap = gaps.reduce((a, b) => a > b ? a : b);

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Schedule Gap Warning'),
          ],
        ),
        content: Text(
          'You have selected time slots with gaps. The largest gap is ${maxGap.inHours}h ${maxGap.inMinutes % 60}m.\n\n'
              'This may create an inefficient schedule for the technician. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _rejectComplaint(String reason) async {
    if (reason.isEmpty) {
      _showError('Please provide a reason for rejection.');
      return;
    }

    setState(() {
      _isRejecting = true;
    });

    try {
      await _firestore.collection('complaint').doc(widget.complaintId).update({
        'reportStatus': 'Rejected',
        'rejectionReason': reason,
        'isRead': false,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'lastStatusChangedAt': FieldValue.serverTimestamp(),
        'reviewedOn': FieldValue.serverTimestamp(),
        'statusChangeCount': FieldValue.increment(1),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Technician'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
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
              const Icon(Icons.schedule,
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

          // Step 1: Duration Input
          _buildDurationInput(),

          if (estimatedDurationHours != null && slotsNeeded > 0) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Step 2: Calendar
            if (isLoadingDates)
              const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                  ))
            else ...[
              _buildCalendar(),
              _buildCalendarLegend(),
            ],
          ],

          if (_selectedDay != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Step 3: Time Slot Selection
            _buildTimeSlotSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.timer, color: Color(0xFF7C3AED), size: 20),
            SizedBox(width: 8),
            Text(
              'Step 1: Estimated Duration (hours)',
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
            hintText: 'Enter hours (e.g., 2)',
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
            if (hours != null && hours > 0) {
              setState(() {
                estimatedDurationHours = hours;
                slotsNeeded = (hours * 60 / TimeSlotCalculator.slotDurationMinutes).ceil();
                selectedTimeSlots.clear();
                _selectedDay = null;
              });
              _calculateAvailableDates();

              // Scroll to calendar
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                }
              });
            } else {
              setState(() {
                estimatedDurationHours = null;
                slotsNeeded = 0;
                selectedTimeSlots.clear();
                availableDates.clear();
                datesStatus.clear();
              });
            }
          },
        ),
        if (slotsNeeded > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'You need to select $slotsNeeded time slots (${slotsNeeded * 30} minutes total)',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7C3AED),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.calendar_today, color: Color(0xFF7C3AED), size: 20),
            SizedBox(width: 8),
            Text(
              'Step 2: Select Date',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TableCalendar(
          firstDay: DateTime.now(),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) {
            if (_selectedDay == null) return false;
            return TimeSlotCalculator.isSameDay(_selectedDay!, day);
          },
          enabledDayPredicate: (day) {
            final normalized = DateTime(day.year, day.month, day.day);
            return availableDates.contains(normalized);
          },
          onDaySelected: (selectedDay, focusedDay) {
            final normalized = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
            if (!availableDates.contains(normalized)) return;

            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
              selectedTimeSlots.clear();

              availableTimeSlots = TimeSlotCalculator.generateTimeSlots(
                selectedDate: selectedDay,
                existingBookings: technicianBookings,
              );
            });

            Future.delayed(const Duration(milliseconds: 300), () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            });
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
            disabledBuilder: (context, day, focusedDay) {
              return _buildCalendarDay(day, false, false, isDisabled: true);
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
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
            _loadTechnicianBookings(selectedTechnicianId!);
          },
        ),
      ],
    );
  }

  Widget _buildCalendarDay(DateTime day, bool isSelected, bool isToday, {bool isDisabled = false}) {
    final normalized = DateTime(day.year, day.month, day.day);
    final isAvailable = availableDates.contains(normalized);
    final dateStatus = datesStatus[normalized];

    Color backgroundColor;
    Color textColor;

    if (isDisabled || dateStatus == null) {
      // Date is outside range or no status calculated
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade400;
    } else if (isSelected) {
      // Selected date - purple
      backgroundColor = const Color(0xFF7C3AED);
      textColor = Colors.white;
    } else if (isToday && isAvailable) {
      // Today and available - light purple
      backgroundColor = const Color(0xFF7C3AED).withOpacity(0.3);
      textColor = Colors.black;
    } else if (dateStatus == 'red') {
      // No slots available - red
      backgroundColor = Colors.red.shade200;
      textColor = Colors.white;
    } else if (dateStatus == 'yellow') {
      // Has bookings but slots available - yellow
      backgroundColor = Colors.yellow.shade200;
      textColor = Colors.black;
    } else if (dateStatus == 'green') {
      // Completely free - green
      backgroundColor = Colors.green.shade200;
      textColor = Colors.black;
    } else {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade400;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildLegendItem('Free', Colors.green.shade200),
          _buildLegendItem('Partial', Colors.yellow.shade200),
          _buildLegendItem('Full', Colors.red.shade200),
          _buildLegendItem('Selected', const Color(0xFF7C3AED)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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

    final slotsSelected = selectedTimeSlots.length;
    final gaps = TimeSlotCalculator.calculateGaps(selectedTimeSlots);
    final hasLargeGap = gaps.any((gap) => gap.inMinutes > 30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Step 3: Select Time Slots',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: slotsSelected < slotsNeeded
                ? Colors.orange.shade50
                : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: slotsSelected < slotsNeeded
                  ? Colors.orange.shade200
                  : Colors.green.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    slotsSelected < slotsNeeded
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle,
                    color: slotsSelected < slotsNeeded
                        ? Colors.orange
                        : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Selected: $slotsSelected / $slotsNeeded slots',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: slotsSelected < slotsNeeded
                          ? Colors.orange.shade900
                          : Colors.green.shade900,
                    ),
                  ),
                ],
              ),
              if (hasLargeGap) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Warning: You have gaps in your schedule!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
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

  Widget _buildTimeSlotCard(TimeSlot slot) {
    final isSelected = selectedTimeSlots.any((s) =>
        s.startTime.isAtSameMomentAs(slot.startTime));

    return GestureDetector(
      onTap: slot.isAvailable
          ? () {
        setState(() {
          if (isSelected) {
            selectedTimeSlots.removeWhere((s) =>
                s.startTime.isAtSameMomentAs(slot.startTime));
          } else {
            selectedTimeSlots.add(slot);
            selectedTimeSlots.sort((a, b) =>
                a.startTime.compareTo(b.startTime));
          }
        });
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
              slot.isAvailable
                  ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                  : Icons.block,
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                selectedTimeSlots.clear();
                availableTimeSlots.clear();
                availableDates.clear();
                datesStatus.clear();
                technicianBookings.clear();
                estimatedDurationHours = null;
                slotsNeeded = 0;
                _durationController.clear();
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          selectedTimeSlots.clear();
          availableTimeSlots.clear();
          availableDates.clear();
          datesStatus.clear();
          estimatedDurationHours = null;
          slotsNeeded = 0;
          _durationController.clear();
        });
        await _loadTechnicianBookings(technician['id']);
        
        // Auto-scroll to duration input after loading bookings
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            );
          }
        });
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
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat(Icons.build,
                    technician['maintenanceField'] ?? 'N/A', Colors.grey[600]!),
                _buildStat(Icons.phone, technician['phoneNo'] ?? 'N/A',
                    Colors.grey[600]!),
                _buildStat(Icons.assignment,
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
}