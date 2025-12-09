import 'package:flutter/material.dart';

class CompletedRepair2Screen extends StatelessWidget {
  final String reportId;
  final String status;
  final String completedDate;
  final String assignedTechnician;
  final String damageCategory;
  final String damageLocation;
  final String inventoryDamage;
  final String inventoryDamageTitle;
  final String duration;
  final String technicianNotes;
  final String reportedOn;

  const CompletedRepair2Screen({
    super.key,
    required this.reportId,
    required this.status,
    required this.completedDate,
    required this.assignedTechnician,
    required this.damageCategory,
    required this.damageLocation,
    required this.inventoryDamage,
    required this.inventoryDamageTitle,
    required this.duration,
    required this.technicianNotes,
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
                      _buildDetailItem('Completed On', completedDate),
                      const Divider(height: 1),
                      _buildDetailItem('Assigned Technician', assignedTechnician),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Category', damageCategory),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Location', damageLocation),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Title', inventoryDamageTitle),
                      const Divider(height: 1),
                      _buildDetailItem('Inventory Damage', inventoryDamage),
                      const Divider(height: 1),
                      _buildDetailItem('Duration', duration),
                      const Divider(height: 1),
                      _buildDetailItem('Technician Notes', technicianNotes),
                      const Divider(height: 1),
                      _buildDetailItem('Reported On', reportedOn, isLast: true),
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