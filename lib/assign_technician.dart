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

  // Get available technicians matching the complaint category
  Stream<List<Map<String, dynamic>>> getAvailableTechniciansStream() {
    // Map complaint category to maintenance field
    String maintenanceField = _mapCategoryToMaintenanceField(widget.complaint.category);
    
    return _firestore
        .collection('technician')
        .where('availability', isEqualTo: true)
        .where('maintenanceField', isEqualTo: maintenanceField)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Map complaint categories to technician maintenance fields
  String _mapCategoryToMaintenanceField(String category) {
    // Adjust this mapping based on your actual categories
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
      // Create a reference to the complaint document
      DocumentReference complaintRef = _firestore.collection('complaint').doc(widget.complaintId);
      
      // Update complaint with assigned technician and change status
      await complaintRef.update({
        'reportStatus': 'In Progress',
        'assignedTechnicianId': selectedTechnicianId,
        'assignedTechnicianName': selectedTechnicianData!['technicianName'],
        'assignedTechnicianNo': selectedTechnicianData!['technicianNo'],
        'assignedDate': FieldValue.serverTimestamp(),
      });

      // Add complaint reference to technician's tasksAssigned array
      await _firestore.collection('technician').doc(selectedTechnicianId).update({
        'tasksAssigned': FieldValue.arrayUnion([complaintRef]),
      });

      setState(() {
        isAssigning = false;
      });

      // Show success message and return to previous page
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assigned ${selectedTechnicianData!['technicianName']} successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
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
          // Complaint Details Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complaint Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Title', widget.complaint.title),
                _buildDetailRow('Category', widget.complaint.category),
                _buildDetailRow('Priority', widget.complaint.priority),
                _buildDetailRow('Student ID', widget.complaint.studentId),
                _buildDetailRow('Room', widget.complaint.room),
              ],
            ),
          ),

          // Available Technicians List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Available Technicians',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _mapCategoryToMaintenanceField(widget.complaint.category),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: getAvailableTechniciansStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                final technicians = snapshot.data ?? [];

                if (technicians.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No available technicians found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'for ${_mapCategoryToMaintenanceField(widget.complaint.category)} maintenance',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: technicians.length,
                  itemBuilder: (context, index) {
                    final technician = technicians[index];
                    final isSelected = selectedTechnicianId == technician['id'];
                    
                    return _buildTechnicianCard(technician, isSelected);
                  },
                );
              },
            ),
          ),

          // Assign Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isAssigning ? null : assignTechnician,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: isAssigning
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Assign Selected Technician',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
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
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianCard(Map<String, dynamic> technician, bool isSelected) {
    return GestureDetector(
      onTap: () {
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
                offset: const Offset(0, 2),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Selection Circle
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF7C3AED) : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),

            // Technician Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
              child: Text(
                technician['technicianName']?.substring(0, 1).toUpperCase() ?? 'T',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Technician Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    technician['technicianName'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${technician['technicianNo'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.build, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        technician['maintenanceField'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        technician['phoneNo'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
