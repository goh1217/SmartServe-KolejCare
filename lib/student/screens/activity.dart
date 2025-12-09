import 'package:flutter/material.dart';
import 'activity/ongoingrepair.dart';
//import 'activity/completedrepair.dart';
import 'activity/completedrepair2.dart';
import 'activity/completed/rating.dart';
import 'activity/completed/tips.dart';
import 'activity/scheduledrepair.dart';
import 'activity/rejectedrepair.dart';
import 'activity/waitappro.dart';
import 'student_make_complaints.dart';
import '../complaint_form_screen.dart';
import '../home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../profile.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // Format Firestore timestamps and other date values into a readable string.
  String formatTimestampFriendly(dynamic ts) {
    try {
      if (ts == null) return 'No date';
      DateTime dt;
      if (ts is Timestamp) dt = ts.toDate().toLocal();
      else if (ts is DateTime) dt = ts.toLocal();
      else dt = DateTime.tryParse(ts.toString())?.toLocal() ?? DateTime.now().toLocal();
      return DateFormat('d MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return ts?.toString() ?? 'No date';
    }
  }
  int _selectedIndex = 2; // default to activity tab

  // Resolve a technician name for display. Use the `assignedTo` path to
  // locate the technician document, extract the technician id from the path
  // and then read the technician document to get the name. This avoids
  // relying on stored duplicated fields like `assignedTechnicianName`.
  Future<String> _getTechnicianName(Map<String, dynamic> data) async {
    try {
      final assignedTo = (data['assignedTo'] ?? '').toString();
      if (assignedTo.isNotEmpty) {
        final parts = assignedTo.split('/').where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          final possibleId = parts.last;
          final doc = await FirebaseFirestore.instance.collection('technician').doc(possibleId).get();
          if (doc.exists) {
            final m = doc.data() as Map<String, dynamic>?;
            final name = (m?['technicianName'] ?? m?['name'] ?? '').toString();
            if (name.isNotEmpty) return name;
          }
        }
      }

      // As a last resort, try a direct technician id field (legacy `technicianID`)
      final techId = (data['technicianID'] ?? '').toString();
      if (techId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('technician').doc(techId).get();
        if (doc.exists) {
          final m = doc.data() as Map<String, dynamic>?;
          final name = (m?['technicianName'] ?? m?['name'] ?? '').toString();
          if (name.isNotEmpty) return name;
        }
      }

      return '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    String formatTimestamp(dynamic ts) {
      try {
        DateTime dt;
        if (ts == null) return 'No date';
        if (ts is Timestamp) {
          dt = ts.toDate().toLocal();
        } else if (ts is DateTime) {
          dt = ts.toLocal();
        } else {
          // try parse string
          dt = DateTime.tryParse(ts.toString())?.toLocal() ?? DateTime.now().toLocal();
        }
        return DateFormat('d MMM yyyy, hh:mm a').format(dt);
      } catch (_) {
        return ts?.toString() ?? 'No date';
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SafeArea(
          child: Container(
            color: const Color(0xFFF5F5F7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: Color(0xFF5E4DB2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Activity',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.notifications, color: Color(0xFF5E4DB2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Ongoing Repairs Section (dynamic from Firestore)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Ongoing Repairs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: (() {
                          final user = FirebaseAuth.instance.currentUser;
                          final uid = user?.uid ?? '';
                          final qBase = FirebaseFirestore.instance.collection('complaint').where('reportStatus', isEqualTo: 'Ongoing');
                          if (uid.isNotEmpty) {
                            final possible = [uid, '/collection/student/$uid', '/collection/student'];
                            return qBase.where('reportBy', whereIn: possible).snapshots();
                          }
                          return qBase.snapshots();
                        })(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(child: Text('Error: ${snapshot.error}')),
                            );
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          final uid = user?.uid ?? '';
                          final email = user?.email ?? '';

                          final docs = snapshot.data?.docs ?? [];

                          final userDocs = docs.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final reportBy = (data['reportBy'] ?? '').toString();
                            final reportByEmail = (data['reportByEmail'] ?? data['email'] ?? '').toString();

                            if (reportByEmail.isNotEmpty && email.isNotEmpty) {
                              if (reportByEmail == email) return true;
                            }

                            if (uid.isNotEmpty && reportBy.contains(uid)) return true;
                            if (email.isNotEmpty && reportBy.contains(email)) return true;

                            // legacy handling
                            if (reportBy == '/collection/student') return true;
                            if (reportBy.contains('/student')) return true;

                            return false;
                          }).toList();

                          if (userDocs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('No ongoing repairs.')),
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: userDocs.map((d) {
                              final data = d.data() as Map<String, dynamic>;
                              // Title: leave blank when no field present
                              final title = (data['inventoryDamage'] ?? data['damageCategory'] ?? data['complaintID'] ?? '').toString();

                              final dateField = data['assignedDate'] ?? data['scheduledDate'] ?? data['reportedDate'] ?? data['reportedOn'];
                              final dateStr = formatTimestampFriendly(dateField);

                              final item = ActivityItem(
                                title: title,
                                status: data['reportStatus']?.toString() ?? 'Ongoing',
                                date: dateStr,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OngoingRepairScreen(complaintId: d.id),
                                  ),
                                ),
                              );

                              return _buildActivityItem(context, item);
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scheduled Section (dynamic from Firestore: reportStatus == 'Ongoing')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Approved', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: (() {
                          final user = FirebaseAuth.instance.currentUser;
                          final uid = user?.uid ?? '';
                          final qBase = FirebaseFirestore.instance.collection('complaint').where('reportStatus', isEqualTo: 'Approved');
                          if (uid.isNotEmpty) {
                            final possible = [uid, '/collection/student/$uid', '/collection/student'];
                            return qBase.where('reportBy', whereIn: possible).snapshots();
                          }
                          return qBase.snapshots();
                        })(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(child: Text('Error: ${snapshot.error}')),
                            );
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          final uid = user?.uid ?? '';
                          final email = user?.email ?? '';

                          final docs = snapshot.data?.docs ?? [];

                          final userDocs = docs.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final reportBy = (data['reportBy'] ?? '').toString();
                            final reportByEmail = (data['reportByEmail'] ?? data['email'] ?? '').toString();

                            if (reportByEmail.isNotEmpty && email.isNotEmpty) {
                              if (reportByEmail == email) return true;
                            }

                            if (uid.isNotEmpty && reportBy.contains(uid)) return true;
                            if (email.isNotEmpty && reportBy.contains(email)) return true;

                            // legacy handling
                            if (reportBy == '/collection/student') return true;
                            if (reportBy.contains('/student')) return true;

                            return false;
                          }).toList();

                          if (userDocs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('No approved items.')),
                            );
                          }



                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: userDocs.map((d) {
                              final data = d.data() as Map<String, dynamic>;
                              final title = (data['inventoryDamageTitle'] ?? data['damageCategory'] ?? data['complaintID'] ?? 'No title').toString();
                              final reported = data['reportedDate'] ?? data['reportedOn'] ?? data['reportedAt'];
                              final scheduledField = data['scheduledDate'];
                              final dateToShow = scheduledField ?? reported;
                              final dateStr = formatTimestampFriendly(dateToShow);

                              final item = ActivityItem(
                                title: title,
                                status: data['reportStatus']?.toString() ?? 'Approved',
                                date: dateStr,
                                onTap: () async {
                                  final techName = await _getTechnicianName(data);
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ScheduledRepairScreen(
                                        reportId: (data['complaintID'] ?? d.id).toString(),
                                        status: data['reportStatus']?.toString() ?? 'Approved',
                                        scheduledDate: dateStr,
                                        assignedTechnician: techName.isNotEmpty
                                          ? techName
                                          : (data['assignedTo'] ?? '').toString(),
                                        damageCategory: (data['damageCategory'] ?? '').toString(),
                                        damageLocation: (data['damageLocation'] ?? '').toString(),
                                        inventoryDamageTitle: data['inventoryDamageTitle'] ?? '',
                                        inventoryDamage: (data['inventoryDamage'] ?? '').toString(),
                                        expectedDuration: (data['expectedDuration'] ?? '').toString(),
                                        reportedOn: dateStr,
                                        // onEditRequest: () async {
                                        //   // Call function inside ScheduledRepairScreen to pick date and update Firestore
                                        //   _editScheduledDate(context, d.id, scheduledField);
                                        // },
                                        // onCancelRequest: () {
                                        //   // optional cancel logic
                                        // },
                                      ),
                                    ),
                                  );
                                },
                              );

                              return _buildActivityItem(context, item); // <- inside map closure
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Rejected Section (dynamic from Firestore)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Rejected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: (() {
                          final user = FirebaseAuth.instance.currentUser;
                          final uid = user?.uid ?? '';
                          final qBase = FirebaseFirestore.instance.collection('complaint').where('reportStatus', isEqualTo: 'Rejected');
                          if (uid.isNotEmpty) {
                            final possible = [uid, '/collection/student/$uid', '/collection/student'];
                            return qBase.where('reportBy', whereIn: possible).snapshots();
                          }
                          return qBase.snapshots();
                        })(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(child: Text('Error: \\${snapshot.error}')),
                            );
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          final uid = user?.uid ?? '';
                          final email = user?.email ?? '';

                          final docs = snapshot.data?.docs ?? [];

                          final userDocs = docs.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final reportBy = (data['reportBy'] ?? '').toString();
                            final reportByEmail = (data['reportByEmail'] ?? data['email'] ?? '').toString();

                            // Prefer exact email match when available
                            if (reportByEmail.isNotEmpty && email.isNotEmpty) {
                              if (reportByEmail == email) return true;
                            }

                            // Match new-style reportBy that contains uid or email
                            if (uid.isNotEmpty && reportBy.contains(uid)) return true;
                            if (email.isNotEmpty && reportBy.contains(email)) return true;

                            // --- Legacy data handling ---
                            // Some older documents stored reportBy as a literal path
                            // like '/collection/student' or '/student/<id>'. Include
                            // those entries so they are visible to the user until
                            // a DB migration is done.
                            if (reportBy == '/collection/student') return true;
                            if (reportBy.contains('/student')) return true;

                            return false;
                          }).toList();

                          if (userDocs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('No rejected complaints.')),
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: userDocs.map((d) {
                              final data = d.data() as Map<String, dynamic>;
                              final title = (data['inventoryDamageTitle'] ?? data['damageCategory'] ?? 'No title').toString();

                              // Use the stored DB value exactly as-is (string if stored as string).
                              final rawDate = data['reportedDate'] ?? data['reportedOn'];
                              final String dateText = formatTimestampFriendly(rawDate);

                              return _buildActivityItem(
                                context,
                                ActivityItem(
                                  title: title,
                                  status: 'Rejected on',
                                  date: dateText,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RejectedRepairScreen(
                                        status: data['reportStatus'] ?? 'Rejected',
                                        damageCategory: data['damageCategory'] ?? '',
                                        inventoryDamageTitle: data['inventoryDamageTitle'] ?? '',
                                        inventoryDamage: data['inventoryDamage'] ?? '',
                                        reportedOn: dateText,
                                        reviewedOn: formatTimestampFriendly(data['reviewedOn']),
                                        reviewedBy: (data['reviewedBy'] ?? '').toString(),
                                        rejectionReason: (data['rejectionReason'] ?? '').toString(),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Waiting Approval Section (dynamic from Firestore)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Waiting Approval', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: (() {
                          final user = FirebaseAuth.instance.currentUser;
                          final uid = user?.uid ?? '';
                          final qBase = FirebaseFirestore.instance.collection('complaint').where('reportStatus', isEqualTo: 'Pending');
                          if (uid.isNotEmpty) {
                            final possible = [uid, '/collection/student/$uid', '/collection/student'];
                            return qBase.where('reportBy', whereIn: possible).snapshots();
                          }
                          return qBase.snapshots();
                        })(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(child: Text('Error: \\${snapshot.error}')),
                            );
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          final uid = user?.uid ?? '';
                          final email = user?.email ?? '';

                          final docs = snapshot.data?.docs ?? [];

                          // Filter pending complaints that belong to the current user.
                          final userDocs = docs.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final reportBy = (data['reportBy'] ?? '').toString();
                            final reportByEmail = (data['reportByEmail'] ?? data['email'] ?? '').toString();

                            if (reportByEmail.isNotEmpty && email.isNotEmpty) {
                              if (reportByEmail == email) return true;
                            }

                            if (uid.isNotEmpty && reportBy.contains(uid)) return true;
                            if (email.isNotEmpty && reportBy.contains(email)) return true;

                            return false;
                          }).toList();

                          if (userDocs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('No pending complaints.')),
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: userDocs.map((d) {
                              final data = d.data() as Map<String, dynamic>;
                              final title = (data['inventoryDamageTitle'] ?? data['damageCategory'] ?? 'No title').toString();

                              String dateText = 'No date';
                              final reportedTs = data['reportedDate'];
                              try {
                                dateText = formatTimestamp(reportedTs ?? data['reportedOn']);
                              } catch (_) {}

                              final item = ActivityItem(
                                title: title,
                                status: 'Submitted on',
                                date: dateText,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WaitingApprovalScreen(
                                      reportStatus: data['reportStatus'] ?? 'Pending',
                                      damageCategory: data['damageCategory'] ?? '',
                                      inventoryDamageTitle: data['inventoryDamageTitle'] ?? '',
                                      inventoryDamage: data['inventoryDamage'] ?? '',
                                      reportedOn: dateText,
                                    ),
                                  ),
                                ),
                              );

                              return _buildActivityItem(context, item);
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Completed Section (dynamic from Firestore)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Completed Repairs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: (() {
                          final user = FirebaseAuth.instance.currentUser;
                          final uid = user?.uid ?? '';
                          final qBase = FirebaseFirestore.instance.collection('complaint').where('reportStatus', isEqualTo: 'Completed');
                          if (uid.isNotEmpty) {
                            final possible = [uid, '/collection/student/$uid', '/collection/student'];
                            return qBase.where('reportBy', whereIn: possible).snapshots();
                          }
                          return qBase.snapshots();
                        })(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(child: Text('Error: \\${snapshot.error}')),
                            );
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          final uid = user?.uid ?? '';
                          final email = user?.email ?? '';

                          final docs = snapshot.data?.docs ?? [];

                          final userDocs = docs.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final reportBy = (data['reportBy'] ?? '').toString();
                            final reportByEmail = (data['reportByEmail'] ?? data['email'] ?? '').toString();
                            if (reportByEmail.isNotEmpty && email.isNotEmpty) {
                              if (reportByEmail == email) return true;
                            }
                            if (uid.isNotEmpty && reportBy.contains(uid)) return true;
                            if (email.isNotEmpty && reportBy.contains(email)) return true;
                            return false;
                          }).toList();

                          if (userDocs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text('No completed repairs.')),
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: userDocs.map((d) {
                              final data = d.data() as Map<String, dynamic>;
                              final title = (data['inventoryDamageTitle'] ?? data['damageCategory'] ?? 'No title').toString();

                              String dateText = 'No date';
                              final completedTs = data['completedDate'] ?? data['reportedDate'];
                              try {
                                dateText = formatTimestamp(completedTs);
                              } catch (_) {}

                              // For each completed item, check if there's already a rating in Firestore.
                              // Use a FutureBuilder so the UI shows the Rate button disabled when a record exists.
                              // robust complaint id candidates
                              final idA = (data['complaintID'] ?? '').toString();
                              final idB = d.id.toString();
                              final candidates = [idA, idB].where((s) => s.isNotEmpty).toList();

                              final Future<QuerySnapshot> futureRating = candidates.isNotEmpty
                                  ? FirebaseFirestore.instance.collection('rating').where('complaintID', whereIn: candidates).limit(1).get()
                                  : FirebaseFirestore.instance.collection('rating').where('complaintID', isEqualTo: idB).limit(1).get();

                              return FutureBuilder<QuerySnapshot>(
                                future: futureRating,
                                builder: (context, ratingSnap) {
                                  final hasRating = ratingSnap.hasData && (ratingSnap.data?.docs.isNotEmpty ?? false);

                                  final item = ActivityItem(
                                    title: title,
                                    status: 'Completed on',
                                    date: dateText,
                                    showActions: true,
                                    onTap: () async {
                                      final techName = await _getTechnicianName(data);
                                      if (!mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CompletedRepair2Screen(
                                            reportId: data['complaintID'] ?? d.id,
                                            status: data['reportStatus'] ?? 'Completed',
                                            completedDate: dateText,
                                            assignedTechnician: techName.isNotEmpty ? techName : (data['assignedTo'] ?? '').toString(),
                                            damageCategory: data['damageCategory'] ?? '',
                                            damageLocation: data['damageLocation'] ?? '',
                                            inventoryDamageTitle: data['inventoryDamageTitle'] ?? '',
                                            inventoryDamage: data['inventoryDamage'] ?? '',
                                            duration: data['duration'] ?? '',
                                            technicianNotes: data['technicianNotes'] ?? '',
                                            reportedOn: (data['reportedOn'] ?? data['reportedDate'] ?? '').toString(),
                                          ),
                                        ),
                                      );
                                    },
                                    onRateTap: hasRating
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => RatingPage(
                                                  complaintId: data['complaintID'] ?? d.id,
                                                  technicianId: (data['technicianID'] ?? data['assignedTo'] ?? '').toString(),
                                                ),
                                              ),
                                            ),
                                    onTipsTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const TipsPage()),
                                    ),
                                  );

                                  return _buildActivityItem(context, item);
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const ComplaintFormScreen()),
        ),
        backgroundColor: const Color(0xFF5E4DB2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // replaced old bottom nav with modern rounded BottomAppBar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  /// Bottom Navigation Bar with modern rounded design
  /// Uses ClipRRect for smooth rounded top corners
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
                // Empty space for the central FAB
                const SizedBox(width: 60),
                _buildNavItem(Icons.description_rounded, 2),
                _buildNavItem(Icons.person_outline, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Individual navigation item with smooth scaling animation
  /// Active state shows darker purple with slight scale effect
  Widget _buildNavItem(IconData icon, int index) {
    final bool isActive = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        // navigate to named routes (ensure these routes exist in main.dart)
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
              ),
            );
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
            color: isActive
                ? const Color(0xFF6C4DF0) // Darker purple when active
                : const Color(0xFFA18CF0), // Soft purple when inactive
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      BuildContext context, {
        required String title,
        required Color backgroundColor,
        required List<ActivityItem> items,
      }) {
    // Wrap each section in a small margin and a rounded white card.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // optional colored accent strip at the top of the card
                  if (backgroundColor != Colors.transparent)
                    Container(
                      height: 8,
                      color: backgroundColor,
                    ),
                  // section items
                  Column(
                    children: items.map((item) => _buildActivityItem(context, item)).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, ActivityItem item) {
    return InkWell(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(
                item.status,
                style: const TextStyle(color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 0,
              child: Text(item.date, style: const TextStyle(color: Colors.grey)),
            ),
          ]),
          if (item.showActions)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                // Rate button: show 'Rated' disabled when already rated
                if (item.onRateTap != null)
                  TextButton.icon(
                    onPressed: item.onRateTap,
                    icon: const Icon(Icons.star_border, size: 16),
                    label: const Text('Rate'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF5E4DB2), padding: EdgeInsets.zero),
                  )
                else
                  TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.star, size: 16, color: Colors.grey),
                    label: const Text('Rated', style: TextStyle(color: Colors.grey)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: item.onTipsTap,
                  icon: const Icon(Icons.attach_money, size: 16),
                  label: const Text('Tips'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF5E4DB2), padding: EdgeInsets.zero),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class ActivityItem {
  final String title;
  final String status;
  final String date;
  final bool showActions;
  final VoidCallback? onTap;
  final VoidCallback? onRateTap;
  final VoidCallback? onTipsTap;

  ActivityItem({
    required this.title,
    required this.status,
    required this.date,
    this.showActions = false,
    this.onTap,
    this.onRateTap,
    this.onTipsTap,
  });
}