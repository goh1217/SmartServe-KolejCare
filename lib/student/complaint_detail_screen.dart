import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final String? complaintID;
  
  const ComplaintDetailScreen({super.key, this.complaintID});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  //report sample
  String reportID = 'RPT-20251125-0234';
  String complaintID = ''; // Store the complaint ID from Firestore
  String reportStatus = 'Scheduled';
  String scheduledDate = '26 Nov 2025 (Time to be scheduled)';
  String assignedTechnician = 'Ahmad Rahim';
  String assignedTo = ''; // Store the technician ID
  String damageCategory = 'Bathroom Fixture';
  String inventoryDamage = 'Shower head damage';
  String expectedDuration = '~1 hour 30 minutes';
  String reportedOn = '20 Nov 2025, 12:40 PM';
  String inventoryDamageTitle = '';
  String damageLocation = '';
  
  // For can't complete reason
  String? cantCompleteReason;
  String? cantCompleteProof;

  bool isCancelled = false;

  bool isEditingDate = false;
  String newScheduledDate = '';

  @override
  void initState() {
    super.initState();
    if (widget.complaintID != null) {
      complaintID = widget.complaintID!;
      _loadComplaintData();
    }
  }

  Future<void> _loadComplaintData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(complaintID)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          reportID = data['complaintID'] ?? 'N/A';
          reportStatus = data['reportStatus'] ?? 'Pending';
          assignedTechnician = data['assignedTechnicianName'] ?? 'Not assigned';
          assignedTo = data['assignedTo'] ?? ''; // Fetch the technician ID
          damageCategory = data['damageCategory'] ?? 'N/A';
          inventoryDamage = data['inventoryDamage'] ?? 'N/A';
          inventoryDamageTitle = data['inventoryDamageTitle'] ?? 'N/A';
          expectedDuration = data['estimatedDurationJobDone']?.toString() ?? '0';
          damageLocation = data['damageLocation'] ?? 'N/A';
          
          // Load can't complete reason and proof
          cantCompleteReason = data['reasonCantComplete'];
          cantCompleteProof = data['reasonCantCompleteProof'];
          
          // Format the scheduled date
          if (data['scheduledDate'] != null) {
            Timestamp ts = data['scheduledDate'] as Timestamp;
            DateTime dt = ts.toDate();
            scheduledDate = '${dt.day} ${_monthName(dt.month)} ${dt.year} (Time to be scheduled)';
          }
          
          // Format the reported date
          if (data['reportedDate'] != null) {
            Timestamp ts = data['reportedDate'] as Timestamp;
            DateTime dt = ts.toDate();
            reportedOn = '${dt.day} ${_monthName(dt.month)} ${dt.year}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'AM' : 'PM'}';
          }
        });
        
        // Debug print to verify assignedTo is loaded
        print('Loaded assignedTo: $assignedTo');
      }
    } catch (e) {
      print('Error loading complaint data: $e');
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  void _cancelRequest() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.yellow),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Are you sure you want to cancel your maintenance request?',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        isCancelled = true;
        reportStatus = 'Cancelled'; // Update repair status
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Your request has been cancelled!',
                style: GoogleFonts.poppins(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.poppins())),
          ],
        ),
      );
    }
  }

  void _editOrConfirm() async {
    if (!isEditingDate) {
      DateTime initialDate = DateTime.now();

      try {
        List<String> parts = scheduledDate.split(" ");
        int day = int.parse(parts[0]);
        int month = _monthNumber(parts[1]);
        int year = int.parse(parts[2]);
        initialDate = DateTime(year, month, day);
      } catch (_) {
        initialDate = DateTime.now();
      }

      DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime.now(),
        lastDate: DateTime(DateTime.now().year + 2),
        helpText: 'Select New Scheduled Date',
      );

      if(pickedDate != null){
        setState(() {
          newScheduledDate =
          "${pickedDate.day.toString().padLeft(2, '0')} ${_monthName(pickedDate.month)} ${pickedDate.year} (Time to be scheduled)";
          isEditingDate = true;
        });
      }
    } else {
      // When confirming the new date, update Firebase
      _updateComplaintWithSuggestedDate();
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

  Future<void> _updateComplaintWithSuggestedDate() async {
    try {
      print('Starting update process...');
      print('complaintID: $complaintID');
      print('assignedTo: $assignedTo');
      print('newScheduledDate: $newScheduledDate');
      
      // Parse the new date to create a timestamp
      List<String> parts = newScheduledDate.split(" ");
      int day = int.parse(parts[0]);
      int month = _monthNumber(parts[1]);
      int year = int.parse(parts[2]);
      DateTime suggestedDateTime = DateTime(year, month, day);
      Timestamp suggestedDateTimestamp = Timestamp.fromDate(suggestedDateTime);

      // Get reference to the complaint document
      final complaintRef = FirebaseFirestore.instance
          .collection('complaint')
          .doc(complaintID);

      // Update the suggestedDate attribute using update() instead of set()
      print('Creating/updating suggestedDate attribute...');
      await complaintRef.update({
        'suggestedDate': suggestedDateTimestamp,
      });
      print('suggestedDate created/updated successfully');

      // Remove the task from the technician's tasksAssigned array
      if (assignedTo.isNotEmpty) {
        print('Removing task from technician: $assignedTo');
        
        // Get the technician document first to verify it exists
        final techDoc = await FirebaseFirestore.instance
            .collection('technician')
            .doc(assignedTo)
            .get();
        
        if (techDoc.exists) {
          print('Technician document found');
          
          // Get current tasksAssigned array
          final tasksAssigned = techDoc.data()?['tasksAssigned'] as List<dynamic>? ?? [];
          print('Current tasksAssigned count: ${tasksAssigned.length}');
          
          // Remove the reference from the tasksAssigned array
          await FirebaseFirestore.instance
              .collection('technician')
              .doc(assignedTo)
              .update({
            'tasksAssigned': FieldValue.arrayRemove([complaintRef])
          });
          print('Task removed from technician successfully');
          
          // Verify removal
          final updatedTechDoc = await FirebaseFirestore.instance
              .collection('technician')
              .doc(assignedTo)
              .get();
          final updatedTasksAssigned = updatedTechDoc.data()?['tasksAssigned'] as List<dynamic>? ?? [];
          print('Updated tasksAssigned count: ${updatedTasksAssigned.length}');
        } else {
          print('Error: Technician document not found for ID: $assignedTo');
        }
      } else {
        print('Warning: assignedTo is empty, cannot remove from technician');
        // Show a warning dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_outlined, size: 48, color: Colors.orange),
                  const SizedBox(height: 12),
                  Text(
                    'Warning: No technician assigned to remove task from.',
                    style: GoogleFonts.poppins(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: GoogleFonts.poppins())),
              ],
            ),
          );
        }
      }

      setState(() {
        scheduledDate = newScheduledDate;
        isEditingDate = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                const SizedBox(height: 12),
                Text(
                  'Your scheduled date has been updated! Admin will review and reassign the task.',
                  style: GoogleFonts.poppins(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.poppins())),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error updating complaint: $e');
      print('Error stack trace: ${StackTrace.current}');
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Error updating scheduled date. Please try again.\nError: $e',
                  style: GoogleFonts.poppins(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.poppins())),
            ],
          ),
        );
      }
    }
  }

  Widget _infoCard(String title, String value) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF90929C))),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complaint Details', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF9F9FB),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _infoCard('ReportID', reportID),
                  _infoCard('Repair Status', reportStatus),
                  if (reportStatus.toLowerCase() != 'pending')
                    _infoCard('Scheduled Date', scheduledDate),
                  _infoCard('Assigned Technician', assignedTechnician),
                  _infoCard('Damage Category', damageCategory),
                  _infoCard('Inventory Damage', inventoryDamage),
                  _infoCard('Expected Duration', expectedDuration),
                  _infoCard('Reported On', reportedOn),
                  
                  // Display can't complete reason if it exists
                  if (cantCompleteReason != null && cantCompleteReason!.isNotEmpty)
                    Container(
                      decoration: _cardDecoration(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reason for Incomplete Task',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: const Color(0xFF90929C))),
                          const SizedBox(height: 4),
                          Text(cantCompleteReason!,
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  
                  // Display can't complete proof image if it exists
                  if (cantCompleteProof != null && cantCompleteProof!.isNotEmpty)
                    Container(
                      decoration: _cardDecoration(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Proof Photo',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: const Color(0xFF90929C))),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              cantCompleteProof!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: 200,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.image, size: 50),
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
                      ),
                    ),
                ],
              ),
            ),
            if (reportStatus.toLowerCase() != 'pending')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isCancelled ? null : _editOrConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8C7DF5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isEditingDate ? 'Confirm' : 'Edit Request',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isCancelled ? null : _cancelRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFA6E6E),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Cancel Request',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}