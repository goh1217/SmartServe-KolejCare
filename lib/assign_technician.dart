import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

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
      // Load booked dates for recommended technician
      await _loadBookedDates(selectedTechnicianId!);
    }
  }

  Future<void> _loadBookedDates(String technicianId) async {
    setState(() {
      isLoadingBookedDates = true;
    });

    try {
      final assignedPath = '/collection/technician/$technicianId';
      final snap = await _firestore
          .collection('complaint')
          .where('assignedTo', isEqualTo: assignedPath)
          .get();

      final Set<DateTime> dates = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        final sd = data['scheduleDate'];
        if (sd is Timestamp) {
          final d = sd.toDate();
          dates.add(DateTime(d.year, d.month, d.day));
        }
      }

      setState(() {
        bookedDates = dates;
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
          content: Text('Please select a schedule date and time'),
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
          else
            _buildCalendar(),
          const SizedBox(height: 16),
          if (_selectedDay != null) ...[
            const Divider(),
            const SizedBox(height: 16),
            _buildTimeSelector(),
            const SizedBox(height: 16),
            if (_selectedTime != null) _buildDurationInput(),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.now(),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      enabledDayPredicate: (day) {
        final dateOnly = DateTime(day.year, day.month, day.day);
        return !bookedDates.contains(dateOnly) &&
            !day.isBefore(DateTime.now().subtract(const Duration(days: 1)));
      },
      onDaySelected: (selectedDay, focusedDay) {
        final dateOnly =
            DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
        if (!bookedDates.contains(dateOnly)) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            _selectedTime = null;
            selectedScheduleDateTime = null;
            selectedEstimatedDurationHours = null;
            _durationController.clear();
          });
        }
      },
      calendarStyle: CalendarStyle(
        selectedDecoration: const BoxDecoration(
          color: Color(0xFF7C3AED),
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        disabledDecoration: const BoxDecoration(
          color: Colors.yellow,
          shape: BoxShape.circle,
        ),
        disabledTextStyle: const TextStyle(color: Colors.black54),
        outsideDaysVisible: false,
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

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Select Time',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: _selectedTime ?? TimeOfDay.now(),
            );
            if (picked != null) {
              setState(() {
                _selectedTime = picked;
                if (_selectedDay != null) {
                  selectedScheduleDateTime = DateTime(
                    _selectedDay!.year,
                    _selectedDay!.month,
                    _selectedDay!.day,
                    picked.hour,
                    picked.minute,
                  );
                }
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedTime != null
                      ? _selectedTime!.format(context)
                      : 'Tap to select time',
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedTime != null
                        ? Colors.black87
                        : Colors.grey[600],
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
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
                bookedDates.clear();
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
}