import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:owtest/models/repair_destination.dart';
import 'package:owtest/widgets/location_selection_card.dart';

/// Example: Integrating RepairDestination into Complaint Form
/// 
/// This shows how to replace 'damageLocation' string with the new
/// RepairDestination model for structured location data.

class ComplaintFormWithRepairDestination extends StatefulWidget {
  const ComplaintFormWithRepairDestination({Key? key}) : super(key: key);

  @override
  State<ComplaintFormWithRepairDestination> createState() =>
      _ComplaintFormWithRepairDestinationState();
}

class _ComplaintFormWithRepairDestinationState
    extends State<ComplaintFormWithRepairDestination> with LocationFormMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priorityOptions = ['Low', 'Medium', 'High', 'Urgent'];
  
  String? _selectedPriority;
  RepairDestination? _repairDestination;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedPriority = _priorityOptions[1]; // Default: Medium
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Called when location is selected from LocationSelectionCard
  void _handleLocationChanged(RepairDestination destination) {
    setState(() {
      _repairDestination = destination;
    });
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location selected: ${destination.address}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Validate form before submission
  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    
    if (_repairDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a repair location'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }
    
    return true;
  }

  /// Submit complaint to Firestore
  Future<void> _submitComplaint() async {
    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get student document for auto-population
      final studentDoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .get();

      final studentData = studentDoc.data() ?? {};

      // Create the complaint with RepairDestination
      final complaintRef = await FirebaseFirestore.instance
          .collection('complaints')
          .add({
            // Student info
            'studentId': user.uid,
            'studentName': studentData['name'] ?? user.displayName ?? 'Unknown',
            'studentPhone': studentData['phone'] ?? '',
            'studentEmail': user.email ?? '',
            'residentCollege': studentData['residentCollege'] ?? '',
            
            // Complaint details
            'description': _descriptionController.text.trim(),
            'priority': _selectedPriority,
            
            // NEW: Use RepairDestination instead of damageLocation
            'repairDestination': _repairDestination!.toFirestore(),
            
            // Status tracking
            'reportStatus': 'PENDING',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            
            // No assignment yet
            'assignedTo': null,
            'assignedAt': null,
            
            // Timeline tracking
            'taskStartedAt': null,
            'arrivedAt': null,
            'completedAt': null,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back or to confirmation screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error submitting complaint: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Repair Request'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description field
              const SizedBox(height: 8),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Describe the issue...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe the issue';
                  }
                  if (value.trim().length < 10) {
                    return 'Description must be at least 10 characters';
                  }
                  return null;
                },
              ),

              // Priority field
              const SizedBox(height: 24),
              const Text(
                'Priority',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                items: _priorityOptions.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(priority),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPriority = value);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              // Repair Destination / Location Selection
              const SizedBox(height: 24),
              const Text(
                'Repair Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              LocationSelectionCard(
                onLocationChanged: _handleLocationChanged,
              ),

              // Selected location display
              if (_repairDestination != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Location',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _repairDestination!.address,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Coordinates: ${_repairDestination!.latitude.toStringAsFixed(4)}, '
                        '${_repairDestination!.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_repairDestination!.locationType != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Type: ${_repairDestination!.locationType}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Submit button
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitComplaint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Submit Complaint',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Example: Reading complaint with RepairDestination from Firestore
class ComplaintDetailsExample extends StatelessWidget {
  final String complaintId;

  const ComplaintDetailsExample({
    Key? key,
    required this.complaintId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Details'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('complaints')
            .doc(complaintId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Complaint not found'));
          }

          final complaintData =
              snapshot.data!.data() as Map<String, dynamic>;

          // Parse RepairDestination from Firestore
          final destination = complaintData['repairDestination'] != null
              ? RepairDestination.fromFirestore(
                  complaintData['repairDestination'],
                )
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                _buildSection(
                  'Description',
                  complaintData['description'] ?? 'N/A',
                ),

                // Priority
                _buildSection(
                  'Priority',
                  complaintData['priority'] ?? 'N/A',
                ),

                // Repair Destination (NEW)
                if (destination != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Repair Location',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(destination.address),
                        const SizedBox(height: 8),
                        Text(
                          '${destination.latitude.toStringAsFixed(4)}, '
                          '${destination.longitude.toStringAsFixed(4)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (destination.locationType != null) ...[
                          const SizedBox(height: 8),
                          Text('Type: ${destination.locationType}'),
                        ],
                      ],
                    ),
                  ),
                ],

                // Status
                const SizedBox(height: 16),
                _buildSection(
                  'Status',
                  complaintData['reportStatus'] ?? 'PENDING',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(value),
        const SizedBox(height: 16),
      ],
    );
  }
}
