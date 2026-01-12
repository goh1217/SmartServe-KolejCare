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
  DateTime? updatedScheduledDate;
  bool isDateUpdated = false;
  String scheduledDateDisplay = '';
  String scheduledTimeDisplay = '';
  String estimatedDurationDisplay = '';
  String currentStatus = '';
  String loadedReportId = '';
  String loadedStatus = '';
  String loadedAssignedTechnician = '';
  String loadedDamageCategory = '';
  String loadedDamageLocation = '';
  String loadedInventoryDamage = '';
  String loadedInventoryDamageTitle = '';
  String loadedReportedOn = '';
  String technicianName = '';
  bool isLoadingTechnicianName = true;
  List<String> damagePicList = [];
  int currentDamagePhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadScheduleDateTimeSlots();
    _fetchTechnicianName();
    currentStatus = widget.status; // initialize with original status
  }

  Future<void> _fetchTechnicianName() async {
    try {
      if (widget.assignedTechnician.isEmpty) {
        setState(() {
          technicianName = 'Unknown';
          isLoadingTechnicianName = false;
        });
        return;
      }

      String technicianId = widget.assignedTechnician;

      // If assignedTechnician is a document reference path like "/collection/technician/docId", extract the docId
      if (widget.assignedTechnician.contains('/collection/technician/')) {
        technicianId = widget.assignedTechnician.split('/').last;
        print('Extracted technician ID from path: $technicianId');
      }

      // Fetch technician document directly by ID from technician collection
      final docSnapshot = await FirebaseFirestore.instance
          .collection('technician')
          .doc(technicianId)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          technicianName = docSnapshot.data()?['technicianName'] ?? widget.assignedTechnician;
          isLoadingTechnicianName = false;
        });
        return;
      }

      // If not found in technician collection, try staff collection as fallback
      final staffDocSnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .doc(technicianId)
          .get();

      if (staffDocSnapshot.exists) {
        setState(() {
          technicianName = staffDocSnapshot.data()?['staffName'] ?? widget.assignedTechnician;
          isLoadingTechnicianName = false;
        });
        return;
      }

      // If still not found, try by staffName
      var querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('staffName', isEqualTo: widget.assignedTechnician)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          technicianName = querySnapshot.docs.first.data()['staffName'] ?? widget.assignedTechnician;
          isLoadingTechnicianName = false;
        });
        return;
      }

      // If still not found, assume assignedTechnician is already the name
      setState(() {
        technicianName = widget.assignedTechnician;
        isLoadingTechnicianName = false;
      });
    } catch (e) {
      print('Error fetching technician name: $e');
      setState(() {
        technicianName = widget.assignedTechnician;
        isLoadingTechnicianName = false;
      });
    }
  }

  Future<void> _loadScheduleDateTimeSlots() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.reportId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          await _processScheduleDateTimeSlots(data);
          // Load estimatedDurationJobDone
          setState(() {
            estimatedDurationDisplay =
                data['estimatedDurationJobDone']?.toString() ??
                    widget.expectedDuration;
            
            // Load damagePic as a list (max 3)
            if (data['damagePic'] != null && data['damagePic'] is List) {
              damagePicList = List<String>.from(data['damagePic'] as List);
              // Limit to max 3 pictures
              if (damagePicList.length > 3) {
                damagePicList = damagePicList.sublist(0, 3);
              }
              currentDamagePhotoIndex = 0;
            }
          });
        }
      }
    } catch (e) {
      print('Error loading schedule date time slots: $e');
    }
  }

  Future<void> _processScheduleDateTimeSlots(Map<String, dynamic> data) async {
    try {
      // Process scheduledDateTimeSlot array
      if (data['scheduledDateTimeSlot'] != null &&
          data['scheduledDateTimeSlot'] is List) {
        final slots = (data['scheduledDateTimeSlot'] as List).cast<Timestamp>();

        if (slots.isNotEmpty) {
          final firstSlot = slots[0];
          final dt = TimeSlotHelper.toMalaysiaTime(firstSlot);
          final timeRange = TimeSlotHelper.formatTimeSlots(slots, includeDate: false);

          setState(() {
            scheduledDateDisplay = "${dt.day}/${dt.month}/${dt.year}";
            scheduledTimeDisplay = timeRange ?? '--:--';
          });
        }
      } else if (data['scheduledDate'] != null) {
        Timestamp timestamp = data['scheduledDate'] as Timestamp;
        final dt = TimeSlotHelper.toMalaysiaTime(timestamp);
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour < 12 ? 'AM' : 'PM';

        setState(() {
          scheduledDateDisplay = "${dt.day}/${dt.month}/${dt.year}";
          scheduledTimeDisplay = '$hour:$minute $ampm';
        });
      } else {
        setState(() {
          scheduledDateDisplay = widget.scheduledDate;
          scheduledTimeDisplay = '--:--';
        });
      }
    } catch (e) {
      print('Error processing scheduled date/time: $e');
      setState(() {
        scheduledDateDisplay = widget.scheduledDate;
        scheduledTimeDisplay = '--:--';
      });
    }
  }

  Future<void> _editRequest() async {
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

    if (!proceed) return;

    DateTime initialDate = updatedScheduledDate ?? DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: 'Select New Scheduled Date',
    );

    if (pickedDate != null) {
      try {
        final complaintRef =
        FirebaseFirestore.instance.collection('complaint').doc(widget.reportId);

        final complaintSnapshot = await complaintRef.get();
        final complaintData = complaintSnapshot.data();

        final suggestedDateTimestamp = Timestamp.fromDate(pickedDate);

        // Step 1: create suggestedDate & set reportStatus to Pending
        await complaintRef.update({
          'suggestedDate': suggestedDateTimestamp,
          'reportStatus': 'Pending',
        });

        // Step 2: remove complaint from old technician tasksAssigned
        if (complaintData != null && complaintData['assignedTo'] != null) {
          var assignedToValue = complaintData['assignedTo'];

          String technicianId = '';
          if (assignedToValue is String) {
            if (assignedToValue.contains('/')) {
              technicianId = assignedToValue.split('/').last;
            } else {
              technicianId = assignedToValue;
            }
          } else if (assignedToValue is DocumentReference) {
            technicianId = assignedToValue.id;
          }

          if (technicianId.isNotEmpty) {
            final techRef =
            FirebaseFirestore.instance.collection('technician').doc(technicianId);

            await techRef.update({
              'tasksAssigned': FieldValue.arrayRemove([
                FirebaseFirestore.instance
                    .collection('complaint')
                    .doc(widget.reportId)
              ])
            });
          }
        }

        // Step 3: set assignedTo to null
        await complaintRef.update({'assignedTo': null});

        // Fetch latest reportStatus
        final updatedDoc = await complaintRef.get();
        final latestStatus = updatedDoc.data()?['reportStatus']?.toString() ?? widget.status;

        setState(() {
          updatedScheduledDate = pickedDate;
          isDateUpdated = true;
          scheduledDateDisplay =
          '${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}';
          scheduledTimeDisplay = '--:--';
          currentStatus = latestStatus; // update status in UI
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Scheduled date updated successfully! Admin will review and reassign.')),
        );
      } catch (e) {
        print('Error updating scheduled date: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _cancelRequest() async {
    try {
      final complaintRef =
      FirebaseFirestore.instance.collection('complaint').doc(widget.reportId);

      final complaintSnapshot = await complaintRef.get();
      final complaintData = complaintSnapshot.data();

      // Step 1: Remove this complaint from technician's tasksAssigned
      if (complaintData != null && complaintData['assignedTo'] != null) {
        var assignedToValue = complaintData['assignedTo'];

        String technicianId = '';
        if (assignedToValue is String) {
          if (assignedToValue.contains('/')) {
            technicianId = assignedToValue.split('/').last;
          } else {
            technicianId = assignedToValue;
          }
        } else if (assignedToValue is DocumentReference) {
          technicianId = assignedToValue.id;
        }

        if (technicianId.isNotEmpty) {
          final techRef =
          FirebaseFirestore.instance.collection('technician').doc(technicianId);

          await techRef.update({
            'tasksAssigned': FieldValue.arrayRemove([
              FirebaseFirestore.instance
                  .collection('complaint')
                  .doc(widget.reportId)
            ])
          });
        }
      }

      // Step 2: Set assignedTo to null and reportStatus to Cancelled
      await complaintRef.update({
        'assignedTo': null,
        'reportStatus': 'Cancelled',
      });

      setState(() {
        currentStatus = 'Cancelled'; // Update UI
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request has been cancelled. Please create new complaint report if needed.')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error cancelling request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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

  Widget _buildScheduledDateTimeItem() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Scheduled Date',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              scheduledDateDisplay.isNotEmpty
                  ? scheduledDateDisplay
                  : widget.scheduledDate,
              style: TextStyle(
                fontSize: 15,
                color: isDateUpdated ? const Color(0xFF7C4DFF) : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (scheduledTimeDisplay.isNotEmpty && scheduledTimeDisplay != '--:--') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Scheduled Time',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: scheduledTimeDisplay
                    .split(', ')
                    .map(
                      (timeSlot) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      timeSlot,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                    .toList(),
              ),
            ),
          ],
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
                      _buildDetailItem(
                        'Report Status',
                        currentStatus,
                        valueColor: currentStatus == 'Pending'
                            ? const Color(0xFF7C4DFF)
                            : null,
                      ),
                      const Divider(height: 1),
                      _buildScheduledDateTimeItem(),
                      const Divider(height: 1),
                      _buildDetailItem('Assigned Technician', isLoadingTechnicianName ? 'Loading...' : technicianName),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Category', widget.damageCategory),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Location', widget.damageLocation),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Title', widget.inventoryDamageTitle),
                      const Divider(height: 1),
                      _buildDetailItem('Inventory Damage', widget.inventoryDamage),
                      const Divider(height: 1),
                      _buildDetailItem(
                          'Expected Duration (hours)',
                          estimatedDurationDisplay.isNotEmpty
                              ? estimatedDurationDisplay
                              : widget.expectedDuration),
                      const Divider(height: 1),
                      _buildDetailItem('Reported On', widget.reportedOn),
                      if (damagePicList.isNotEmpty) ...[
                        const Divider(height: 1),
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Damage Photo${damagePicList.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (damagePicList.length == 1)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    damagePicList[0],
                                    width: double.infinity,
                                    height: 250,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: double.infinity,
                                        height: 250,
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
                                )
                              else
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Left arrow button
                                        IconButton(
                                          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              currentDamagePhotoIndex = (currentDamagePhotoIndex - 1 + damagePicList.length) % damagePicList.length;
                                            });
                                          },
                                        ),
                                        // Image display
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              damagePicList[currentDamagePhotoIndex],
                                              width: double.infinity,
                                              height: 250,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: double.infinity,
                                                  height: 250,
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
                                        ),
                                        // Right arrow button
                                        IconButton(
                                          icon: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              currentDamagePhotoIndex = (currentDamagePhotoIndex + 1) % damagePicList.length;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    // Image counter
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '${currentDamagePhotoIndex + 1} / ${damagePicList.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
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

// TimeSlotHelper class
class TimeSlotHelper {
  static DateTime toMalaysiaTime(Timestamp timestamp) {
    return timestamp.toDate().toUtc().add(const Duration(hours: 8));
  }

  static String? formatTimeSlots(List<Timestamp> slots, {bool includeDate = true}) {
    if (slots.isEmpty) return null;

    List<DateTime> times = slots.map((ts) => toMalaysiaTime(ts)).toList();
    times.sort();

    List<String> ranges = [];
    int i = 0;

    while (i < times.length) {
      DateTime start = times[i];
      DateTime end = start.add(const Duration(minutes: 30));

      int j = i + 1;
      while (j < times.length) {
        if (times[j].difference(end).inMinutes == 0) {
          end = times[j].add(const Duration(minutes: 30));
          j++;
        } else {
          break;
        }
      }

      String startTime = _formatTime(start);
      String endTime = _formatTime(end);
      ranges.add('$startTime - $endTime');

      i = j;
    }

    return ranges.join(', ');
  }

  static String _formatTime(DateTime dt) {
    int hour = dt.hour;
    int minute = dt.minute;
    String period = hour >= 12 ? 'PM' : 'AM';

    if (hour > 12) {
      hour -= 12;
    } else if (hour == 0) {
      hour = 12;
    }

    String minuteStr = minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr $period';
  }
}
