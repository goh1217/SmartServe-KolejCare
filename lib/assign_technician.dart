import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  String? selectedTechnicianId;
  Map<String, dynamic>? selectedTechnicianData;
  bool isAssigning = false;
  Map<String, dynamic>? recommendedTechnicianData;
  bool isManualSelection = false;

  // New variables for rejection
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
    super.dispose();
  }

  Future<void> _getRecommendedTechnician() async {
    final technicians = await getAvailableTechniciansStream().first;
    if (technicians.isNotEmpty) {
      setState(() {
        recommendedTechnicianData = technicians.first;
        // Pre-select the recommended technician
        selectedTechnicianId = recommendedTechnicianData!['id'];
        selectedTechnicianData = recommendedTechnicianData;
      });
    }
  }

  // Get available technicians matching the complaint category and sort them by workload
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
        // Ensure tasksAssigned is a list to prevent errors
        data['tasksAssigned'] =
            data['tasksAssigned'] is List ? data['tasksAssigned'] : [];
        return data;
      }).toList();

      // Sort technicians by the number of tasks assigned in ascending order
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

    setState(() {
      isAssigning = true;
    });

    try {
      DocumentReference complaintRef =
          _firestore.collection('complaint').doc(widget.complaintId);

      await complaintRef.update({
        'reportStatus': 'In Progress',
        'assignedTechnicianId': selectedTechnicianId,
        'assignedTechnicianName': selectedTechnicianData!['technicianName'],
        'assignedTechnicianNo': selectedTechnicianData!['technicianNo'],
        'assignedDate': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('technician').doc(selectedTechnicianId).update({
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

  // New method to handle complaint rejection
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
      await _firestore.collection('complaint').doc(widget.complaintId).update({
        'reportStatus': 'Rejected',
        'rejectionReason': reason,
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

  // New method to show the rejection dialog
  void _showRejectDialog() {
    // Clear the controller before showing the dialog
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
                Navigator.pop(context); // Close dialog
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

                // Show recommendation view or manual selection list
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

  // Builds the recommendation view with accept/reject options
  Widget _buildRecommendationView(List<Map<String, dynamic>> technicians) {
    if (recommendedTechnicianData == null) {
      // This can happen briefly while the first stream result is being processed
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }

    return SingleChildScrollView(
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
          _buildRecommendationButtons(),
        ],
      ),
    );
  }

  // Builds the list for manual technician selection
  Widget _buildManualSelectionView(List<Map<String, dynamic>> technicians) {
    return Column(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _mapCategoryToMaintenanceField(widget.complaint.category),
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
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: technicians.length,
            itemBuilder: (context, index) {
              final technician = technicians[index];
              final isSelected = selectedTechnicianId == technician['id'];
              return _buildTechnicianCard(technician, isSelected);
            },
          ),
        ),
        _buildManualActionButtons(), // Show assign button for manual selection
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
                selectedTechnicianId = null; // Deselect on switching
                selectedTechnicianData = null;
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    // For manual selection, the card is tappable. For recommendation, it is not.
    return GestureDetector(
      onTap: isRecommendation
          ? null
          : () {
              setState(() {
                selectedTechnicianId = technician['id'];
                selectedTechnicianData = technician;
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
                  // Selection Circle for manual list
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
