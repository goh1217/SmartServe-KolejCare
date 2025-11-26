import 'package:flutter/material.dart';

class RejectedRepairScreen extends StatelessWidget {
  final String? reportId; // Made optional with ?
  final String status;
  final String damageCategory;
  final String inventoryDamage;
  final String reportedOn;
  final String reviewedOn;
  final String reviewedBy;
  final String rejectionReason;

  const RejectedRepairScreen({
    super.key,
    this.reportId, // Optional parameter
    required this.status,
    required this.damageCategory,
    required this.inventoryDamage,
    required this.reportedOn,
    required this.reviewedOn,
    required this.reviewedBy,
    required this.rejectionReason,
  });

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
                      _buildDetailItem('Report ID', reportId ?? 'N/A', isFirst: true),
                      const Divider(height: 1),
                      _buildDetailItem('Report Status', status),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Category', damageCategory),
                      const Divider(height: 1),
                      _buildDetailItem('Inventory Damage', inventoryDamage),
                      const Divider(height: 1),
                      _buildDetailItem('Reported On', reportedOn),
                      const Divider(height: 1),
                      _buildDetailItem('Reviewed On', reviewedOn),
                      const Divider(height: 1),
                      _buildDetailItem('Reviewed By', reviewedBy),
                      const Divider(height: 1),
                      _buildDetailItem('Reason for Rejection', rejectionReason, isLast: true),
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