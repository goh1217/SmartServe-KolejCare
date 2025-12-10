import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScheduledRepairScreen extends StatefulWidget {
  final String reportId;
  final String status;
  final String scheduledDate; // original string for initial display
  final String assignedTechnician;
  final String damageCategory;
  final String damageLocation;
  final String inventoryDamage;
  final String inventoryDamageTitle;
  final String expectedDuration;
  final String reportedOn;

  const ScheduledRepairScreen({
    super.key,
    required this.reportId,
    required this.status,
    required this.scheduledDate,
    required this.assignedTechnician,
    required this.damageCategory,
    required this.damageLocation,
    required this.inventoryDamageTitle,
    required this.inventoryDamage,
    required this.expectedDuration,
    required this.reportedOn,
  });

  @override
  State<ScheduledRepairScreen> createState() => _ScheduledRepairScreenState();
}

class _ScheduledRepairScreenState extends State<ScheduledRepairScreen> {
  DateTime? updatedScheduledDate; // store actual updated date
  bool isDateUpdated = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _editRequest() async {
    // Show warning dialog first
    bool proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warning'),
        content: const Text(
          'Only request to change scheduled reparation date when necessary.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I understand'),
          ),
        ],
      ),
    ) ?? false;

    if (!proceed) return; // User cancelled

    // Show date picker
    DateTime initialDate = updatedScheduledDate ?? DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: 'Select New Scheduled Date',
    );

    if (pickedDate != null) {
      // Update Firestore
      final complaintRef =
      FirebaseFirestore.instance.collection('complaint').doc(widget.reportId);

      // Fetch current complaint data
      final complaintSnapshot = await complaintRef.get();
      final complaintData = complaintSnapshot.data();

      // Remove this complaintID from old technician's tasksAssigned
      // if (complaintData != null && complaintData['assignedTo'] != null) {
      //   final oldTechId = complaintData['assignedTo'];
      //   final techRef = FirebaseFirestore.instance.collection('technician').doc(oldTechId);
      //   final techSnapshot = await techRef.get();
      //   final techData = techSnapshot.data();
      //   if (techData != null && techData['tasksAssigned'] != null) {
      //     List tasks = List.from(techData['tasksAssigned']);
      //     tasks.removeWhere((task) =>
      //     task is DocumentReference && task.id == widget.reportId);
      //     await techRef.update({'tasksAssigned': tasks});
      //   }
      // }

      // Update complaint: scheduledDate, reportStatus, assignedTo & reviewedBy
      await complaintRef.update({
        'scheduledDate': Timestamp.fromDate(pickedDate),
        'reportStatus': 'Pending',
        'assignedTo': null,
        'reviewedBy': null,
      });

      setState(() {
        updatedScheduledDate = pickedDate;
        isDateUpdated = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduled date updated successfully!')),
      );
    }
  }

  int _monthNumber(String shortName) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months.indexOf(shortName);
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  String _formatScheduledDate() {
    if (updatedScheduledDate != null) {
      return "${updatedScheduledDate!.day.toString().padLeft(2, '0')} "
          "${_monthName(updatedScheduledDate!.month)} "
          "${updatedScheduledDate!.year} (Time to be scheduled)";
    } else {
      return "${widget.scheduledDate} (Time to be scheduled)";
    }
  }

  Future<void> _cancelRequest() async {
    await FirebaseFirestore.instance
        .collection('complaint')
        .doc(widget.reportId)
        .update({'reportStatus': 'Cancelled'});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request has been cancelled')),
    );

    Navigator.pop(context);
  }

  Widget _buildDetailItem(String label, String value,
      {bool isFirst = false, bool isLast = false, Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: valueColor ?? Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Report Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem('Repair Status', widget.status),
                      const Divider(height: 1),
                      _buildDetailItem(
                        'Scheduled Date',
                        _formatScheduledDate(),
                        valueColor: isDateUpdated ? const Color(0xFF7C4DFF) : null,
                      ),
                      const Divider(height: 1),
                      _buildDetailItem('Assigned Technician', widget.assignedTechnician),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Category', widget.damageCategory),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Location', widget.damageLocation),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Title', widget.inventoryDamageTitle),
                      const Divider(height: 1),
                      _buildDetailItem('Inventory Damage', widget.inventoryDamage),
                      const Divider(height: 1),
                      _buildDetailItem('Expected Duration', widget.expectedDuration),
                      const Divider(height: 1),
                      _buildDetailItem('Reported On', widget.reportedOn),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _editRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Edit Scheduled Date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cancelRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF5350),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Cancel Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
