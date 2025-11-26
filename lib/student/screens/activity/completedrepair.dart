import 'package:flutter/material.dart';
// Add this import

class CompletedRepairScreen extends StatelessWidget {
  const CompletedRepairScreen({super.key});

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
                _buildDetailItem('Report ID', 'RPT-20251118-087', isFirst: true),
                const Divider(height: 1),
                _buildDetailItem('Repair Status', 'Completed'),
                const Divider(height: 1),
                _buildDetailItem('Service Category', 'Electrical'),
                const Divider(height: 1),
                _buildDetailItem('Inventory Damage', 'Electric shortage'),
                const Divider(height: 1),
                _buildDetailItem('Duration', '1 hour'),
                const Divider(height: 1),
                _buildDetailItem('Assigned Technician', 'Lim Wei Seng'),
                const Divider(height: 1),
                _buildDetailItem('Technician Notes',
                    'Identified a burnt cable in the wall socket circuit. Replaced the damaged wire and reset the circuit breaker. Power restored and tested - all outlets functioning.'),
                const Divider(height: 1),
                _buildDetailItem('Completed On', '18 Nov 2025, 01:18 PM', isLast: true),
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