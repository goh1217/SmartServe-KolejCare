import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'staff_complaints.dart';
import 'assign_technician.dart';

class ComplaintDetailsPage extends StatefulWidget {
  final Complaint complaint;

  const ComplaintDetailsPage({Key? key, required this.complaint})
    : super(key: key);

  @override
  _ComplaintDetailsPageState createState() => _ComplaintDetailsPageState();
}

class _ComplaintDetailsPageState extends State<ComplaintDetailsPage> {
  late Future<Map<String, dynamic>> _complaintDetailsFuture;
  late String _selectedPriority;
  bool _isUpdatingPriority = false;

  @override
  void initState() {
    super.initState();
    _complaintDetailsFuture = _fetchComplaintDetails();
    _selectedPriority = widget.complaint.priority;
  }

  Future<Map<String, dynamic>> _fetchComplaintDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.complaint.id)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('Error fetching complaint details: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchTechnicianDetails(
    String technicianId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('technician')
          .doc(technicianId)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('Error fetching technician details: $e');
      return {};
    }
  }

  String _formatDateTime(dynamic value) {
    if (value is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(value.toDate());
    } else if (value is DateTime) {
      return DateFormat.yMMMd().add_jm().format(value);
    }
    return value?.toString() ?? 'N/A';
  }

  String _calculateResolutionTime(
    dynamic reportedDate,
    dynamic lastStatusUpdate,
  ) {
    try {
      DateTime start = reportedDate is Timestamp
          ? reportedDate.toDate()
          : reportedDate as DateTime;
      DateTime end = lastStatusUpdate is Timestamp
          ? lastStatusUpdate.toDate()
          : lastStatusUpdate as DateTime;

      Duration difference = end.difference(start);
      int hours = difference.inHours;
      int minutes = difference.inMinutes % 60;
      int days = difference.inDays;

      if (days > 0) {
        return '$days day${days > 1 ? 's' : ''} $hours hour${hours > 1 ? 's' : ''}';
      } else if (hours > 0) {
        return '$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}';
      } else {
        return '$minutes minute${minutes > 1 ? 's' : ''}';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  void _navigateToAssignTechnician() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignTechnicianPage(
          complaintId: widget.complaint.id,
          complaint: widget.complaint,
        ),
      ),
    );

    if (result != null && result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Technician assigned successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      // Refresh the details
      setState(() {
        _complaintDetailsFuture = _fetchComplaintDetails();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Complaint Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF7C3AED),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _complaintDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text('Error loading details: ${snapshot.error}'),
            );
          }

          final data = snapshot.data!;
          final status = widget.complaint.status;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(status),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.complaint.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Student: ${widget.complaint.studentName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (data['inventoryDamageTitle'] != null &&
                              (data['inventoryDamageTitle'] as String).isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Inventory: ${data['inventoryDamageTitle']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          Text(
                            'Room: ${widget.complaint.room}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Base Details
                _buildSectionTitle('Complaint Details'),
                const SizedBox(height: 12),
                _buildDetailRow('Category', widget.complaint.category),
                _buildPriorityRow(status, data),
                _buildDetailRow(
                  'Submitted',
                  DateFormat.yMMMd().add_jm().format(
                    widget.complaint.submitted,
                  ),
                ),
                if (widget.complaint.suggestedDate != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Suggested Reschedule Date',
                    DateFormat.yMMMd().format(
                      widget.complaint.suggestedDate!,
                    ),
                  ),
                ],
                _buildDetailRow(
                  'Damage Location',
                  data['damageLocation']?.toString() ?? 'N/A',
                ),
                _buildDetailRow(
                  'Room Entry Consent',
                  data['roomEntryConsent']?.toString() ?? 'N/A',
                ),
                if (data['inventoryDamageTitle'] != null &&
                    (data['inventoryDamageTitle'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Inventory Title',
                    data['inventoryDamageTitle']?.toString() ?? 'N/A',
                  ),
                ],
                if (data['inventoryDamage'] != null &&
                    (data['inventoryDamage'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Damage Description',
                    data['inventoryDamage']?.toString() ?? 'N/A',
                  ),
                ],

                // Damage Picture
                if (data['damagePic'] != null) ...[
                  const SizedBox(height: 16),
                  _buildSectionTitle('Damage Picture'),
                  const SizedBox(height: 12),
                  if (data['damagePic'] is String && (data['damagePic'] as String).isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        data['damagePic'] as String,
                        fit: BoxFit.cover,
                        height: 300,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('Image not available'),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ] else if (data['damagePic'] is List && (data['damagePic'] as List).isNotEmpty) ...[
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (data['damagePic'] as List).length,
                        itemBuilder: (context, index) {
                          final imageUrl = (data['damagePic'] as List)[index]?.toString() ?? '';
                          if (imageUrl.isEmpty) {
                            return const SizedBox(width: 8);
                          }
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: 250,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 250,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Text('Image not available'),
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],

                // Reason Can't Complete (if applicable)
                if (widget.complaint.reasonCantComplete != null &&
                    widget.complaint.reasonCantComplete!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionTitle('Previous Attempt Issue'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.redAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason: ${widget.complaint.reasonCantComplete}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.complaint.cantCompleteCount > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Attempts: ${widget.complaint.cantCompleteCount}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Proof photo for previous attempt (if available)
                if (widget.complaint.reasonCantCompleteProof != null &&
                    widget.complaint.reasonCantCompleteProof!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionTitle('Proof Photo'),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.complaint.reasonCantCompleteProof!,
                      fit: BoxFit.cover,
                      height: 300,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('Image not available'),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Status-specific details
                if (status == 'Approved') ...[
                  const SizedBox(height: 20),
                  _buildApprovedSection(data),
                ] else if (status == 'Ongoing') ...[
                  const SizedBox(height: 20),
                  _buildOngoingSection(data),
                ] else if (status == 'Completed') ...[
                  const SizedBox(height: 20),
                  _buildCompletedSection(data),
                ] else if (status == 'Rejected') ...[
                  const SizedBox(height: 20),
                  _buildRejectedSection(data),
                ] else if (status == 'Cancelled') ...[
                  const SizedBox(height: 20),
                  _buildCancelledSection(data),
                ],

                // Assign Technician Button for Pending
                if (status == 'Pending') ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToAssignTechnician,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Assign Technician'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildApprovedSection(Map<String, dynamic> data) {
    final scheduledSlots =
        data['scheduledDateTimeSlot'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Scheduled Time Slots'),
        const SizedBox(height: 12),
        if (scheduledSlots.isEmpty)
          Text(
            'No time slots scheduled yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          )
        else
          Column(
            children: scheduledSlots.asMap().entries.map((entry) {
              int index = entry.key;
              dynamic slot = entry.value;

              DateTime slotTime = slot is Timestamp
                  ? slot.toDate()
                  : slot as DateTime;
              DateTime slotEndTime = slotTime.add(const Duration(minutes: 30));

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Slot ${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(slotTime),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${DateFormat.Hm().format(slotTime)} - ${DateFormat.Hm().format(slotEndTime)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '(30 min)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildOngoingSection(Map<String, dynamic> data) {
    final assignedToPath = data['assignedTo'] as String?;

    return FutureBuilder<Map<String, dynamic>>(
      future: assignedToPath != null && assignedToPath.isNotEmpty
          ? _fetchTechnicianDetails(assignedToPath.split('/').last)
          : Future.value({}),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Assigned Technician'),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const CircularProgressIndicator()
            else if (snapshot.hasData && snapshot.data!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  border: Border.all(color: Colors.purple[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Technician No',
                      snapshot.data!['technicianNo']?.toString() ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Name',
                      snapshot.data!['technicianName']?.toString() ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Email',
                      snapshot.data!['email']?.toString() ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Phone',
                      snapshot.data!['phoneNo']?.toString() ?? 'N/A',
                    ),
                  ],
                ),
              )
            else
              Text(
                'No technician assigned.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCompletedSection(Map<String, dynamic> data) {
    final assignedToPath = data['assignedTo'] as String?;
    final resolutionTime = _calculateResolutionTime(
      widget.complaint.submitted,
      data['lastStatusUpdate'],
    );

    return FutureBuilder<Map<String, dynamic>>(
      future: assignedToPath != null && assignedToPath.isNotEmpty
          ? _fetchTechnicianDetails(assignedToPath.split('/').last)
          : Future.value({}),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Resolution'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'Completed On',
                    _formatDateTime(data['lastStatusUpdate']),
                  ),
                  _buildDetailRow('Total Resolution Time', resolutionTime),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Assigned Technician'),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const CircularProgressIndicator()
            else if (snapshot.hasData && snapshot.data!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  border: Border.all(color: Colors.purple[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Technician No',
                      snapshot.data!['technicianNo']?.toString() ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Name',
                      snapshot.data!['technicianName']?.toString() ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Email',
                      snapshot.data!['email']?.toString() ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Phone',
                      snapshot.data!['phoneNo']?.toString() ?? 'N/A',
                    ),
                  ],
                ),
              )
            else
              Text(
                'No technician assigned.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRejectedSection(Map<String, dynamic> data) {
    final rejectionReason = data['rejectionReason'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Rejection Details'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red[50],
            border: Border.all(color: Colors.red[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reason:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rejectionReason ?? 'No reason provided.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCancelledSection(Map<String, dynamic> data) {
    final lastStatusUpdate = data['lastStatusUpdate'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Cancellation Details'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildDetailRow(
            'Cancelled On',
            _formatDateTime(lastStatusUpdate),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
        ],
      ),
    );
  }

  Future<void> _updatePriority(String newPriority) async {
    setState(() {
      _isUpdatingPriority = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.complaint.id)
          .update({'urgencyLevel': newPriority});

      setState(() {
        _selectedPriority = newPriority;
        _complaintDetailsFuture = _fetchComplaintDetails();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Priority updated to $newPriority'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update priority: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPriority = false;
        });
      }
    }
  }

  Widget _buildPriorityRow(String status, Map<String, dynamic> data) {
    final choices = ['High', 'Medium', 'Minor'];
    final dataPriority = data['urgencyLevel']?.toString() ?? widget.complaint.priority;

    // If not pending, show a read-only detail row (do not allow editing)
    if (status != 'Pending') {
      return _buildDetailRow('Priority', dataPriority);
    }

    // For pending complaints, show editable dropdown (admin can change urgencyLevel)
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Priority',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: _selectedPriority.isNotEmpty ? _selectedPriority : dataPriority,
              items: choices
                  .map((p) => DropdownMenuItem<String>(
                        value: p,
                        child: Text(p),
                      ))
                  .toList(),
              onChanged: _isUpdatingPriority
                  ? null
                  : (val) {
                      if (val != null && val != (dataPriority)) {
                        _updatePriority(val);
                      }
                    },
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.yellow[700]!;
      case 'Approved':
        return Colors.purple[700]!;
      case 'Ongoing':
        return Colors.blue[700]!;
      case 'Completed':
        return Colors.green[700]!;
      case 'Rejected':
        return Colors.red[700]!;
      case 'Cancelled':
        return Colors.grey[700]!;
      default:
        return const Color(0xFF7C3AED);
    }
  }
}
