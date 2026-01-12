import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RejectedRepairScreen extends StatefulWidget {
  final String? reportId; // Made optional with ?
  final String status;
  final String damageCategory;
  final String damageLocation;
  final String inventoryDamage;
  final String inventoryDamageTitle;
  final String reportedOn;
  final String reviewedOn;
  final String reviewedBy;
  final String rejectionReason;

  const RejectedRepairScreen({
    super.key,
    this.reportId, // Optional parameter
    required this.status,
    required this.damageCategory,
    required this.damageLocation,
    required this.inventoryDamage,
    required this.inventoryDamageTitle,
    required this.reportedOn,
    required this.reviewedOn,
    required this.reviewedBy,
    required this.rejectionReason,
  });

  @override
  State<RejectedRepairScreen> createState() => _RejectedRepairScreenState();
}

class _RejectedRepairScreenState extends State<RejectedRepairScreen> {
  String adminName = '';
  bool isLoadingAdminName = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminName();
  }

  Future<void> _fetchAdminName() async {
    try {
      if (widget.reviewedBy.isEmpty) {
        setState(() {
          adminName = 'Unknown';
          isLoadingAdminName = false;
        });
        return;
      }

      String staffId = widget.reviewedBy;

      // If reviewedBy is a document reference path like "/collection/staff/docId", extract the docId
      if (widget.reviewedBy.contains('/collection/staff/')) {
        staffId = widget.reviewedBy.split('/').last;
        print('Extracted staff ID from path: $staffId');
      }

      // Fetch staff document directly by ID
      final docSnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .doc(staffId)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          adminName = docSnapshot.data()?['staffName'] ?? widget.reviewedBy;
          isLoadingAdminName = false;
        });
        return;
      }

      // If not found by ID, try to query by staffName
      var querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('staffName', isEqualTo: widget.reviewedBy)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          adminName = querySnapshot.docs.first.data()['staffName'] ?? widget.reviewedBy;
          isLoadingAdminName = false;
        });
        return;
      }

      // If still not found, try by staffId
      querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('staffId', isEqualTo: widget.reviewedBy)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          adminName = querySnapshot.docs.first.data()['staffName'] ?? widget.reviewedBy;
          isLoadingAdminName = false;
        });
      } else {
        // If still not found, assume reviewedBy is already the name
        setState(() {
          adminName = widget.reviewedBy;
          isLoadingAdminName = false;
        });
      }
    } catch (e) {
      print('Error fetching admin name: $e');
      setState(() {
        adminName = widget.reviewedBy;
        isLoadingAdminName = false;
      });
    }
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
                      // _buildDetailItem('Report ID', reportId ?? 'N/A', isFirst: true),
                      // const Divider(height: 1),
                      _buildDetailItem('Report Status', widget.status),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Category', widget.damageCategory),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Location', widget.damageLocation),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Title', widget.inventoryDamageTitle),
                      const Divider(height: 1),
                      _buildDetailItem('Inventory Damage', widget.inventoryDamage),
                      const Divider(height: 1),
                      _buildDetailItem('Reported On', widget.reportedOn),
                      const Divider(height: 1),
                      _buildDetailItem('Reviewed On', widget.reviewedOn),
                      const Divider(height: 1),
                      _buildDetailItem('Reviewed By', isLoadingAdminName ? 'Loading...' : adminName),
                      const Divider(height: 1),
                      _buildDetailItem('Reason for Rejection', widget.rejectionReason, isLast: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value,
      {bool isFirst = false, bool isLast = false}) {
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
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Example usage:
// Navigator.push(
//   context,
//   MaterialPageRoute(
//     builder: (context) => RejectedRepairScreen(
//       reportId: 'RPT123456',
//       status: 'Rejected',
//       damageCategory: 'Ceiling Fan',
//       inventoryDamage: 'The fan rotates too slowly',
//       reportedOn: '19 Nov 2025, 11:58 PM',
//       reviewedOn: '20 Nov 2025, 09:11 AM',
//       reviewedBy: 'Mr. Amirul',
//       rejectionReason: 'The issue is not considered a valid maintenance case. The fan speed is functioning normally based on inspection.',
//     ),
//   ),
// );