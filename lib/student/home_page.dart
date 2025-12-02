import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:owtest/student/complaint_form_screen.dart';
import 'services/weatherService.dart';

import 'notification_page.dart';
import 'donate_page.dart';
import 'screens/activity.dart';

// Simple model to hold complaint summary information for UI
class ComplaintSummary {
  final String id;
  final String rawStatus;
  final double progress;
  final String displayText;
  final String description;
  final String category;
  final int? createdAt;

  ComplaintSummary({
    required this.id,
    required this.rawStatus,
    required this.progress,
    required this.displayText,
    required this.description,
    required this.category,
    this.createdAt,
  });
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool showAlert = true;
  WeatherData? weatherData;
  bool isLoadingWeather = true;
  String weatherError = '';
  // Firestore fields
  String studentName = '';
  String matricNo = '';
  bool isLoadingStudent = true;

  // Complaint progress
  double complaintProgress = 0.0; // 0.0 - 1.0
  String complaintStatusLabel = 'No reports';
  String complaintStatusDescription = '';
  // raw status value from complaint doc (lowercase) for logic decisions
  String complaintRawStatus = '';
  // damage category from complaint doc (e.g. "Electrical", "Furniture")
  String complaintDamageCategory = '';
  // List of complaint summaries for multi-complaint support
  List<ComplaintSummary> complaintSummaries = [];
  StreamSubscription<QuerySnapshot>? _complaintSub;
  String? _studentDocId;

  @override
  void initState() {
    super.initState();
    _loadWeather();
    _startComplaintListener();
    fetchStudentData();
  }

  @override
  void dispose() {
    _complaintSub?.cancel();
    super.dispose();
  }

  // Small status bar widget that reflects complaint progress and status
  Widget _buildStatusBar() {
    // Primary label is the inventory damage title; status will be shown below the progress bar
    final titleLabel = complaintDamageCategory.replaceAll('\n', ' ');
    final label = titleLabel.isNotEmpty ? titleLabel : complaintStatusLabel.replaceAll('\n', ' ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: complaintProgress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        complaintProgress >= 1.0
                            ? Colors.green
                            : (complaintRawStatus.contains('rejected') ? Colors.red : Colors.deepPurple),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Show status with icon and single percentage below the progress bar
                  Row(
                    children: [
                      Icon(
                        (complaintRawStatus.contains('ongo')
                            ? Icons.build_circle
                            : (complaintRawStatus.contains('completed') ? Icons.check_circle : (complaintRawStatus.contains('rejected') ? Icons.report_problem : Icons.info_outline))),
                        size: 18,
                        color: complaintRawStatus.contains('rejected') ? Colors.red.shade700 : Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          complaintStatusLabel,
                          style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${(complaintProgress * 100).round()}%',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Compact status badge on the right to avoid squeezing the status row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.12)),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.02), blurRadius: 2)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    // choose icon by status
                    (complaintRawStatus.contains('ongo')
                        ? Icons.build_circle
                        : (complaintRawStatus.contains('completed') ? Icons.check_circle : (complaintRawStatus.contains('rejected') ? Icons.report_problem : Icons.info_outline))),
                    size: 18,
                    color: complaintRawStatus.contains('rejected') ? Colors.red.shade700 : Colors.deepPurple,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    // short status label (fallback trimmed)
                    (complaintStatusLabel.length > 16 ? complaintStatusLabel.substring(0, 16) + '...' : complaintStatusLabel),
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  // Build a status bar for a specific complaint summary with remove option
 

Widget _buildStatusBarFor(BuildContext context, ComplaintSummary c, VoidCallback onRemove) {
  final label = c.displayText.replaceAll('\n', ' ');
  final isCompleted = c.rawStatus == 'completed';
  final isRejected = c.rawStatus == 'rejected';
  final isRemovable = isCompleted || isRejected;

  // Get status description based on raw status
  String statusDescription = '';
  if (c.rawStatus == 'pending') {
    statusDescription = 'Your report is being reviewed by our team';
  } else if (c.rawStatus == 'approved') {
    statusDescription = 'Report has been approved and assigned';
  } else if (c.rawStatus == 'rejected') {
    statusDescription = 'Report was not approved';
  } else if (c.rawStatus == 'ongoing') {
    statusDescription = 'Technician is on the way';
  } else if (c.rawStatus == 'completed') {
    statusDescription = 'Repair work has been completed';
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Category title and percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  c.category.isNotEmpty ? c.category : 'Damage Report',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.progress >= 1.0
                      ? Colors.green.shade100
                      : (c.rawStatus.contains('rejected') 
                          ? Colors.red.shade100 
                          : Colors.deepPurple.shade50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: c.progress >= 1.0
                        ? Colors.green.shade300
                        : (c.rawStatus.contains('rejected') 
                            ? Colors.red.shade300 
                            : Colors.deepPurple.shade200),
                  ),
                ),
                child: Text(
                  '${(c.progress * 100).round()}%',
                  style: TextStyle(
                    color: c.progress >= 1.0
                        ? Colors.green.shade700
                        : (c.rawStatus.contains('rejected') 
                            ? Colors.red.shade700 
                            : Colors.deepPurple.shade700),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: c.progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                c.progress >= 1.0 
                    ? Colors.green 
                    : (c.rawStatus.contains('rejected') 
                        ? Colors.red 
                        : Colors.deepPurple),
              ),
            ),
          ),
          
          const SizedBox(height: 10),
          
          // Status row with icon and description
          Row(
            children: [
              Icon(
                (c.rawStatus.contains('ongo')
                    ? Icons.build_circle
                    : (c.rawStatus.contains('completed') 
                        ? Icons.check_circle 
                        : (c.rawStatus.contains('rejected') 
                            ? Icons.report_problem 
                            : Icons.info_outline))),
                size: 18,
                color: c.rawStatus.contains('rejected') 
                    ? Colors.red.shade700 
                    : Colors.deepPurple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (statusDescription.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        statusDescription,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isRemovable) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 14, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Remove',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          // Completion/Rejection message - now with flexible text wrapping
          if (isCompleted) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This report has been completed. You can remove it from your list.',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 11,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isRejected) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.report_problem, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This report was rejected. You can remove it from your list.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 11,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  // Helper to build a ComplaintSummary from a Firestore doc map
  ComplaintSummary _buildSummaryFromDoc(String id, Map<String, dynamic> data) {
    final statusRaw = (data['status'] ?? data['reportStatus'] ?? data['Status'] ?? data['ReportStatus'] ?? '').toString();
    final status = statusRaw.trim();
    final s = status.toLowerCase();

    double progress = 0.0;
    String displayText = '';

    if (s == 'pending') {
      progress = 0.30;
      displayText = 'Under Review';
    } else if (s == 'approved') {
      progress = 0.50;
      displayText = 'Report Approved';
    } else if (s == 'rejected') {
      // Treat rejected reports as completed for UI purposes (100%)
      progress = 1.0;
      displayText = 'Report Rejected';
    } else if (s == 'ongoing') {
      progress = 0.90;
      displayText = 'Technician On The Way';
    } else if (s == 'completed') {
      progress = 1.0;
      displayText = 'Work Completed';
    } 
    /*else {
      progress = 0.0;
      displayText = status.isNotEmpty ? status : 'No Reports';
    }*/

    // Prefer `inventoryDamageTitle` (canonical) over older damageCategory fields
    final categoryRaw = (data['inventoryDamageTitle'] ?? data['inventory_damage_title'] ?? data['inventoryDamage'] ?? data['inventory_title'] ?? data['damageCategory'] ?? data['damage_category'] ?? data['category'] ?? data['damage'] ?? '').toString();
    final category = categoryRaw.isNotEmpty ? categoryRaw : '';

    int? createdMs;
    final createdVal = data['createdAt'] ?? data['timestamp'] ?? data['created'];
    if (createdVal != null) {
      if (createdVal is int) createdMs = createdVal;
      else if (createdVal is double) createdMs = createdVal.toInt();
      else if (createdVal is String) {
        createdMs = int.tryParse(createdVal);
      } else if (createdVal is Timestamp) {
        createdMs = createdVal.millisecondsSinceEpoch;
      }
    }

    return ComplaintSummary(
      id: id,
      rawStatus: s,
      progress: progress,
      displayText: displayText,
      description: '${(progress * 100).round()}%',
      category: category,
      createdAt: createdMs,
    );
  }

  Future<void> _loadComplaintProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;

      if (kDebugMode) print('Loading complaint progress for user uid: $uid');

      if (uid == null) {
        if (kDebugMode) print('No user logged in');
        setState(() {
          complaintSummaries = [];
          complaintProgress = 0.0;
          complaintStatusLabel = 'No reports';
          complaintStatusDescription = '';
          complaintRawStatus = '';
          complaintDamageCategory = '';
        });
        return;
      }

      // Find the student document for this user (we assume student doc has an 'authUid' or uses same email)
      final studentQuery = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();

      String? studentDocId;
      if (studentQuery.docs.isNotEmpty) {
        studentDocId = studentQuery.docs.first.id;
      } else {
        // fallback: try matching by email if authUid not present
        final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        if (userEmail.isNotEmpty) {
          final byEmail = await FirebaseFirestore.instance
              .collection('student')
              .where('email', isEqualTo: userEmail)
              .limit(1)
              .get();
          if (byEmail.docs.isNotEmpty) studentDocId = byEmail.docs.first.id;
        }
      }

      // Query complaints where reportBy equals the student doc id (preferred) or the auth uid
      final Set<String> complaintIds = <String>{};
      final List<ComplaintSummary> summaries = [];

      if (studentDocId != null && studentDocId.isNotEmpty) {
        final studentRef = FirebaseFirestore.instance.collection('student').doc(studentDocId);

        // First try where reportBy is stored as a DocumentReference
        final qRef = await FirebaseFirestore.instance
            .collection('complaint')
            .where('reportBy', isEqualTo: studentRef)
            .get();
        for (final d in qRef.docs) {
          complaintIds.add(d.id);
          summaries.add(_buildSummaryFromDoc(d.id, d.data()));
        }

        // Some systems store the reportBy as a path/string. Try common variants.
        final pathVariants = [
          'student/$studentDocId',
          '/student/$studentDocId',
          'collection/student/$studentDocId',
          '/collection/student/$studentDocId',
          studentDocId,
        ];
        for (final variant in pathVariants) {
          if (variant.isEmpty) continue;
          final qS = await FirebaseFirestore.instance
              .collection('complaint')
              .where('reportBy', isEqualTo: variant)
              .get();
          for (final d in qS.docs) {
            if (!complaintIds.contains(d.id)) {
              complaintIds.add(d.id);
              summaries.add(_buildSummaryFromDoc(d.id, d.data()));
            }
          }
        }
      }

      // also check where reportBy equals auth uid (some apps store auth uid)
      final q2 = await FirebaseFirestore.instance.collection('complaint').where('reportBy', isEqualTo: uid).get();
      for (final d in q2.docs) {
        if (!complaintIds.contains(d.id)) {
          complaintIds.add(d.id);
          summaries.add(_buildSummaryFromDoc(d.id, d.data()));
        }
      }

      // If still empty, fall back to complaints referenced in student doc fields (complaintId(s))
      if (summaries.isEmpty && studentDocId != null) {
        final studentDoc = await FirebaseFirestore.instance.collection('student').doc(studentDocId).get();
        final studentData = studentDoc.data() ?? {};
        final singleId = (studentData['complaintID'] ?? studentData['complaintId'] ?? studentData['complaint'] ?? '').toString();
        if (singleId.isNotEmpty) complaintIds.add(singleId);
        final listField = studentData['complaintIds'] ?? studentData['complaintList'] ?? studentData['complaints'];
        if (listField is List) {
          for (final item in listField) {
            final sId = item?.toString() ?? '';
            if (sId.isNotEmpty) complaintIds.add(sId);
          }
        }
        for (final id in complaintIds) {
          final doc = await FirebaseFirestore.instance.collection('complaint').doc(id).get();
          if (doc.exists) summaries.add(_buildSummaryFromDoc(doc.id, doc.data() ?? {}));
        }
      }

      if (summaries.isEmpty) {
        setState(() {
          complaintSummaries = [];
          complaintProgress = 0.0;
          complaintStatusLabel = 'No reports';
          complaintStatusDescription = '';
          complaintRawStatus = '';
          complaintDamageCategory = '';
        });
        return;
      }

      // sort by createdAt descending
      summaries.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));

      final primary = summaries.first;
      setState(() {
        complaintSummaries = summaries;
        complaintProgress = primary.progress;
        complaintStatusLabel = primary.displayText;
        complaintRawStatus = primary.rawStatus;
        complaintStatusDescription = primary.description;
        complaintDamageCategory = primary.category;
      });

      final anyAssigned = summaries.any((c) => c.rawStatus == 'ongoing');
      if (anyAssigned && showAlert && mounted) {
        setState(() => showAlert = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAlertDialog();
        });
      }
    } catch (e) {
      if (kDebugMode) print('ERROR loading complaint progress: $e');
      setState(() {
        complaintSummaries = [];
        complaintProgress = 0.0;
        complaintStatusLabel = 'Error';
        complaintStatusDescription = '';
        complaintRawStatus = '';
        complaintDamageCategory = '';
      });
    }
  }

    // Add this method to your _HomePageState class
    Future<void> _removeCompletedReport(String complaintId) async {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Text('Remove Report?'),
              ],
            ),
            content: const Text(
              'This report is completed. Are you sure you want to remove it from your list?\n\nNote: This will not delete the report from the system, only hide it from your view.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Remove'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        try {
          // Option 1: Mark as archived (recommended - doesn't delete data)
          await FirebaseFirestore.instance.collection('complaint').doc(complaintId).update({
            'isArchived': true,
            'archivedAt': FieldValue.serverTimestamp(),
          });

          // Listener updates UI in real-time; no need to reload manually

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report removed from your list'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (kDebugMode) print('Error archiving complaint: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to remove report'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
      
    }

  // Start a real-time listener for complaints and update UI automatically
  Future<void> _startComplaintListener() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      String sid = '';
      if (uid != null) {
        final q = await FirebaseFirestore.instance.collection('student').where('authUid', isEqualTo: uid).limit(1).get();
        if (q.docs.isNotEmpty) sid = q.docs.first.id;
        else {
          final email = user?.email ?? '';
          if (email.isNotEmpty) {
            final qe = await FirebaseFirestore.instance.collection('student').where('email', isEqualTo: email).limit(1).get();
            if (qe.docs.isNotEmpty) sid = qe.docs.first.id;
          }
        }
      }

      _studentDocId = sid.isNotEmpty ? sid : null;

      // cancel previous subscription if any
      await _complaintSub?.cancel();

      // Listen to complaint collection and filter client-side for student matches
      _complaintSub = FirebaseFirestore.instance.collection('complaint').snapshots().listen((snap) {
        try {
          final List<ComplaintSummary> summaries = [];
          for (final d in snap.docs) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            // Skip archived
            if (data['isArchived'] == true) continue;

            final rb = data['reportBy'] ?? data['reportedBy'];
            bool matches = false;

            // Auto-archive disabled: users must delete/remove rejected reports themselves.

            if (_studentDocId != null && _studentDocId!.isNotEmpty) {
              final sidLocal = _studentDocId!;
              if (rb == null) {
                matches = false;
              } else if (rb is DocumentReference) {
                final path = rb.path;
                if (path.endsWith('/$sidLocal') || path.contains(sidLocal)) matches = true;
              } else {
                final s = rb.toString();
                if (s.contains(sidLocal)) matches = true;
              }
            }

            if (!matches && uid != null) {
              if (rb == uid) matches = true;
              else if (rb is String && rb.contains(uid)) matches = true;
            }

            if (matches) {
              summaries.add(_buildSummaryFromDoc(d.id, data));
            }
          }

          // sort and update state
          summaries.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
          if (kDebugMode) print('Complaint listener: found ${summaries.length} matching items');

          if (summaries.isEmpty) {
            if (mounted) setState(() {
              complaintSummaries = [];
              complaintProgress = 0.0;
              complaintStatusLabel = 'No reports';
              complaintStatusDescription = '';
              complaintRawStatus = '';
              complaintDamageCategory = '';
            });
          } else {
            final primary = summaries.first;
            if (mounted) setState(() {
              complaintSummaries = summaries;
              complaintProgress = primary.progress;
              complaintStatusLabel = primary.displayText;
              complaintRawStatus = primary.rawStatus;
              complaintStatusDescription = primary.description;
              complaintDamageCategory = primary.category;
            });
          }
        } catch (e) {
          if (kDebugMode) print('Error processing complaint snapshot: $e');
        }
      }, onError: (e) {
        if (kDebugMode) print('Complaint listener error: $e');
      });
    } catch (e) {
      if (kDebugMode) print('Error starting complaint listener: $e');
    }
  }


  // Load weather data
  Future<void> _loadWeather() async {
    setState(() {
      isLoadingWeather = true;
      weatherError = '';
    });

    try {
      final weatherService = WeatherService();

      // Get weather by city (Johor Bahru)
      final weather = await weatherService.getWeatherByCity('Johor Bahru');

      setState(() {
        weatherData = weather;
        isLoadingWeather = false;
      });
    } catch (e) {
      setState(() {
        weatherError = 'Failed to load weather';
        isLoadingWeather = false;
      });
      if (kDebugMode) print('Weather error: $e');
    }
  }

  // Bell icon with unread badge (real-time)
  Widget _buildBellIcon() {
    return FutureBuilder<String>(
      future: () async {
        final user = FirebaseAuth.instance.currentUser;
        final uid = user?.uid;
        if (uid == null) return '';
        final q = await FirebaseFirestore.instance.collection('student').where('authUid', isEqualTo: uid).limit(1).get();
        if (q.docs.isNotEmpty) return q.docs.first.id;
        final email = user?.email ?? '';
        if (email.isNotEmpty) {
          final qe = await FirebaseFirestore.instance.collection('student').where('email', isEqualTo: email).limit(1).get();
          if (qe.docs.isNotEmpty) return qe.docs.first.id;
        }
        return '';
      }(),
      builder: (context, snap) {
        final sid = snap.data ?? '';
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const SizedBox(width: 28, height: 28, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }

        final stream = sid.isNotEmpty
            ? FirebaseFirestore.instance.collection('complaint').where('reportBy', isEqualTo: '/collection/student/$sid').where('isRead', isEqualTo: false).snapshots()
            : FirebaseFirestore.instance.collection('complaint').where('isRead', isEqualTo: false).where('reportBy', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '').snapshots();

        return StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, s2) {
            final unread = s2.data?.docs.length ?? 0;
            final hasUnread = unread > 0;
            return InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const NotificationPage()));
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications,
                      color: hasUnread ? Colors.deepPurple : Colors.grey.shade600,
                      size: 28,
                    ),
                    if (hasUnread)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.45), blurRadius: 8, spreadRadius: 2)],
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          child: Center(
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Fetch data from Firestore
  Future<void> fetchStudentData() async {
    setState(() {
      isLoadingStudent = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception("Not logged in");
      }
        final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        final doc = await FirebaseFirestore.instance
          .collection('student')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (doc.docs.isNotEmpty) {
        final data = doc.docs.first.data();
        setState(() {
          studentName = (data['studentName'] ?? '').toString();
          matricNo = (data['matricNo'] ?? '').toString();
          isLoadingStudent = false;
        });
        if (kDebugMode) {
          print('Firestore studentName=${studentName}, matricNo=${matricNo}');
        }
      } else {
        setState(() {
          studentName = 'Unknown';
          matricNo = '';
          isLoadingStudent = false;
        });
        if (kDebugMode) print('Student document not found');
      }
    } catch (e) {
      setState(() {
        studentName = 'Error loading';
        matricNo = '';
        isLoadingStudent = false;
      });
      if (kDebugMode) print('Error fetching student data: $e');
    }
  }

  void _showAlertDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning,
                    color: Colors.orange.shade700,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reminder: Technicians will be visiting for repairs today. Please keep the area clear and be cautious.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Get weather icon based on condition
  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
      case 'drizzle':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      default:
        return Icons.wb_cloudy;
    }
  }

  // Get weather color based on condition
  List<Color> _getWeatherColors(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return [Colors.orange.shade300, Colors.yellow.shade300];
      case 'clouds':
        return [Colors.grey.shade400, Colors.blueGrey.shade300];
      case 'rain':
      case 'drizzle':
        return [Colors.blue.shade400, Colors.indigo.shade300];
      case 'thunderstorm':
        return [Colors.purple.shade400, Colors.deepPurple.shade300];
      default:
        return [Colors.teal.shade300, Colors.blue.shade300];
    }
  }

  // Empty state widget shown when there are no active reports
  Widget _buildEmptyReportsState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // Illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 60,
                  color: Colors.deepPurple.withOpacity(0.3),
                ),
                Positioned(
                  bottom: 25,
                  right: 25,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Active Reports',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any pending complaints.\nEverything looks good!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ComplaintFormScreen(),
                ),
              );
            },
            icon: Icon(Icons.add, size: 18),
            label: const Text('Report an Issue'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepPurple,
              side: BorderSide(color: Colors.deepPurple),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.person, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            isLoadingStudent
                                ? 'Loading...'
                                : (studentName.isNotEmpty ? studentName : 'Guest'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isLoadingStudent && matricNo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              matricNo,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildBellIcon(),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () {
                          FirebaseAuth.instance.signOut();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // (Status bars will be shown in the "Active Reports" section below)

                    // Donate Card
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TipsPage()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.deepPurple, Colors.purple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Make a Donation',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Donate Now',
                                    style: TextStyle(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.volunteer_activism,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // DYNAMIC WEATHER CARD
                    GestureDetector(
                      onTap: _loadWeather, // Tap to refresh
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: weatherData != null
                                ? _getWeatherColors(weatherData!.mainCondition)
                                : [Colors.teal.shade300, Colors.blue.shade300],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: isLoadingWeather
                            ? Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              const SizedBox(height: 8),
                              Text(
                                'Loading weather...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                            : weatherError.isNotEmpty
                            ? Column(
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              weatherError,
                              style: TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              onPressed: _loadWeather,
                              child: Text(
                                'Retry',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        )
                            : weatherData != null
                            ? Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _getWeatherIcon(weatherData!.mainCondition),
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${weatherData!.temperature.round()}°',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    weatherData!.mainCondition.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    weatherData!.cityName,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Humidity: ${weatherData!.humidity}%',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Wind: ${weatherData!.windSpeed.toStringAsFixed(1)} m/s',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Weather description
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to\nrefresh',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                            : const SizedBox(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Active reports section - status bars render here and scroll with the page
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Reports',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        InkWell(
                          onTap: complaintSummaries.any((c) => c.rawStatus == 'ongoing') ? _showAlertDialog : null,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: complaintSummaries.any((c) => c.rawStatus == 'ongoing') ? Colors.deepPurple : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (complaintSummaries.isNotEmpty) ...[
                      ...complaintSummaries.map((c) => _buildStatusBarFor(
                            context,
                            c,
                            () => _removeCompletedReport(c.id),
                          )),
                      const SizedBox(height: 24),
                    ] else ...[
                      const SizedBox(height: 12),
                      _buildEmptyReportsState(),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ComplaintFormScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF5E4DB2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Bottom navigation bar matching `ActivityScreen` style
  Widget _buildBottomNavBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEAE4F9), // Light purple background
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: SizedBox(
            height: 65,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_rounded, 0),
                _buildNavItem(Icons.calendar_today_rounded, 1),
                const SizedBox(width: 60),
                _buildNavItem(Icons.description_rounded, 2),
                _buildNavItem(Icons.settings, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final bool isActive = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        switch (index) {
          case 0:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
            break;
          case 1:
            Navigator.pushNamed(context, '/schedule');
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ActivityScreen()),
            );
            break;
          case 3:
            Navigator.pushNamed(context, '/settings');
            break;
        }
      },
      child: AnimatedScale(
        scale: isActive ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: isActive ? const Color(0xFF6C4DF0) : const Color(0xFFA18CF0),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class ScheduleItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  const ScheduleItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}