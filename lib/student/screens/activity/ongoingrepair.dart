import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'technician_tracking.dart';

class OngoingRepairScreen extends StatelessWidget {
  final String? complaintId;

  const OngoingRepairScreen({super.key, this.complaintId});

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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              future: complaintId != null
                  ? FirebaseFirestore.instance.collection('complaint').doc(complaintId).get()
                  : Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final Map<String, dynamic> data = snap.data?.data() ?? {};
                final id = complaintId ?? data['complaintID'] ?? snap.data?.id ?? '—';
                // derive fields from document
                // (No ETA shown initially; keep parsing available for later if needed.)

                final serviceCategory = (data['damageCategory'] ?? data['category'] ?? '').toString();
                final location = (data['damageLocation'] ?? data['location'] ?? '').toString();
                final issue = (data['inventoryDamage'] ?? data['description'] ?? data['damageDesc'] ?? '').toString();
                // Estimated duration intentionally left blank initially
                final estimatedDuration = (data['estimatedDuration'] ?? data['estimated_time'] ?? '').toString();
                // Resolve technician name by parsing `assignedTo` path and
                // looking up the technician document. This avoids relying on
                // deprecated/duplicated fields such as `assignedTechnicianName`.
                final String assignedToRaw = (data['assignedTo'] ?? '').toString();
                Future<String> technicianFuture() async {
                  try {
                    if (assignedToRaw.isEmpty) return '';
                    final parts = assignedToRaw.split('/').where((s) => s.isNotEmpty).toList();
                    if (parts.isEmpty) return '';
                    final id = parts.last;
                    final doc = await FirebaseFirestore.instance.collection('technician').doc(id).get();
                    if (!doc.exists) return '';
                    final m = doc.data();
                    return (m?['technicianName'] ?? m?['name'] ?? '').toString();
                  } catch (_) {
                    return '';
                  }
                }
                final reportedOn = data['reportedDate'] ?? data['reportedOn'] ?? data['createdAt'];
                String reportedText = '';
                try {
                  if (reportedOn != null) {
                    if (reportedOn is Timestamp) reportedText = DateFormat('d MMM yyyy, hh:mm a').format(reportedOn.toDate().toLocal());
                    else if (reportedOn is String) {
                      final parsed = DateTime.tryParse(reportedOn);
                      if (parsed != null) reportedText = DateFormat('d MMM yyyy, hh:mm a').format(parsed.toLocal());
                    }
                  }
                } catch (_) {
                  reportedText = '';
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem('Report ID', id.toString(), isFirst: true),
                    const Divider(height: 1),
                    _buildDetailItem(
                      'Repair Status',
                      '',  // Empty since we'll use a custom layout
                      trailing: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Technician on route',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<String>(
                            future: technicianFuture(),
                            builder: (context, techSnap) {
                              final techName = techSnap.data ?? '';
                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TechnicianTrackingScreen(
                                        technicianName: techName.isNotEmpty ? techName : 'Technician',
                                        complaintId: complaintId,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'By 1:00 pm',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.map_outlined, size: 14, color: Colors.blue),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _buildDetailItem('Service Category', serviceCategory),
                    const Divider(height: 1),
                    _buildDetailItem('Issue Description', issue),
                    const Divider(height: 1),
                    // Estimated Duration intentionally left blank initially
                    _buildDetailItem('Estimated Duration', estimatedDuration),
                    const Divider(height: 1),
                    _buildDetailItem(
                      'Assigned Technician',
                      '',
                      trailing: FutureBuilder<String>(
                        future: technicianFuture(),
                        builder: (context, techSnap) {
                          final tech = techSnap.data ?? '';
                          return Text(
                            tech.isNotEmpty ? tech : 'Technician',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    _buildDetailItem('Reported On', reportedText, isLast: true),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value,
      {bool isFirst = false, bool isLast = false, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
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
                // show value text if no trailing provided
                if (trailing == null)
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // (no external maps helper - keep the UI simple for now)
}