import 'package:flutter/material.dart';

class ScheduledRepairScreen extends StatelessWidget {
  final String reportId;
  final String status;
  final String scheduledDate;
  final String assignedTechnician;
  final String damageCategory;
  final String inventoryDamage;
  final String expectedDuration;
  final String reportedOn;
  final VoidCallback? onEditRequest;
  final VoidCallback? onCancelRequest;

  const ScheduledRepairScreen({
    super.key,
    required this.reportId,
    required this.status,
    required this.scheduledDate,
    required this.assignedTechnician,
    required this.damageCategory,
    required this.inventoryDamage,
    required this.expectedDuration,
    required this.reportedOn,
    this.onEditRequest,
    this.onCancelRequest,
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
                      _buildDetailItem('Report ID', reportId, isFirst: true),
                      const Divider(height: 1),
                      _buildDetailItem('Repair Status', status),
                      const Divider(height: 1),
                      _buildDetailItem('Scheduled Date', scheduledDate),
                      const Divider(height: 1),
                      _buildDetailItem('Assigned Technician', assignedTechnician),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Category', damageCategory),
                      const Divider(height: 1),
                      _buildDetailItem('Inventory Damage', inventoryDamage),
                      const Divider(height: 1),
                      _buildDetailItem('Expected Duration', expectedDuration),
                      const Divider(height: 1),
                      _buildDetailItem('Reported On', reportedOn, isLast: true),
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
                    onPressed: onEditRequest,
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
                      'Edit Request',
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
                    onPressed: onCancelRequest,
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
//     builder: (context) => ScheduledRepairScreen(
//       reportId: 'RPT-20251125-0234',
//       status: 'Scheduled',
//       scheduledDate: '25 Nov 2025, 10:00 AM',
//       assignedTechnician: 'Ahmad Rahim',
//       damageCategory: 'Bathroom Fixture',
//       inventoryDamage: 'Shower head damage',
//       expectedDuration: '~1 hour 30 minutes',
//       reportedOn: '20 Nov 2025, 12:40 PM',
//       onEditRequest: () {
//         // Handle edit request
//         print('Edit request tapped');
//       },
//       onCancelRequest: () {
//         // Handle cancel request
//         print('Cancel request tapped');
//       },
//     ),
//   ),
// );