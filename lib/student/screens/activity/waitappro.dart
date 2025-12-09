import 'package:flutter/material.dart';

class WaitingApprovalScreen extends StatelessWidget {
  final String reportStatus;
  final String damageCategory;
  final String damageLocation;
  final String inventoryDamage;
  final String inventoryDamageTitle;
  final String reportedOn;

  const WaitingApprovalScreen({
    super.key,
    required this.reportStatus,
    required this.damageCategory,
    required this.damageLocation,
    required this.inventoryDamage,
    required this.inventoryDamageTitle,
    required this.reportedOn,
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
      body: SingleChildScrollView(
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
                _buildDetailItem('Report Status', reportStatus, isFirst: true),
                const Divider(height: 1),
                _buildDetailItem('Damage Category', damageCategory),
                const Divider(height: 1),
                _buildDetailItem('Damage Location', damageLocation),
                const Divider(height: 1),
                _buildDetailItem('Damage Title', inventoryDamageTitle),
                const Divider(height: 1),
                _buildDetailItem('Inventory Damage', inventoryDamage),
                const Divider(height: 1),
                _buildDetailItem('Reported On', reportedOn, isLast: true),
              ],
            ),
          ),
        ),
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
//     builder: (context) => WaitingApprovalScreen(
//       reportStatus: 'Waiting to be approved',
//       damageCategory: 'Door handle',
//       inventoryDamage: 'Door handle is loose',
//       reportedOn: '23 Nov 2025, 01:58 PM',
//     ),
//   ),
// );