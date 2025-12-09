import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:owtest/staff_complaints.dart';
import 'package:owtest/settings_page.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Analytics',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('complaint').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No complaints to analyze.'));
          }

          final allDocs = snapshot.data!.docs;

          // Map each doc to a Future<Complaint>
          final complaintFutures =
          allDocs.map((doc) => Complaint.fromFirestore(doc)).toList();

          // Wait for all Future<Complaint> to complete
          return FutureBuilder<List<Complaint>>(
            future: Future.wait(complaintFutures),
            builder: (context, complaintSnapshot) {
              if (complaintSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (complaintSnapshot.hasError) {
                return Center(
                    child:
                    Text('Error loading complaints: ${complaintSnapshot.error}'));
              }
              if (!complaintSnapshot.hasData || complaintSnapshot.data!.isEmpty) {
                return const Center(child: Text('No complaints available.'));
              }

              final complaints = complaintSnapshot.data!;

              // --- Main Analytics Calculations ---
              final totalComplaints = complaints.length;
              final completedComplaints =
              complaints.where((c) => c.status == 'Completed').toList();
              final completionRate = totalComplaints > 0
                  ? (completedComplaints.length / totalComplaints) * 100
                  : 0.0;

              double totalResolutionHours = 0;
              int resolvedWithDatesCount = 0;

              for (var c in completedComplaints) {
                // Using complaint.submitted and assume a resolvedDate field exists
                // If you have scheduleDate, replace accordingly
                // For demo, let's just simulate average time
                totalResolutionHours += 24; // mock 1 day per completed
                resolvedWithDatesCount++;
              }

              final avgHours = resolvedWithDatesCount > 0
                  ? totalResolutionHours / resolvedWithDatesCount
                  : 0.0;

              final categoryCounts =
              _calculateBreakdown(complaints, (c) => c.category);
              final statusCounts =
              _calculateBreakdown(complaints, (c) => c.status);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('System Analytics'),
                    const SizedBox(height: 12),
                    _buildSummaryCards(totalComplaints, completionRate, avgHours),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Complaints by Category'),
                    const SizedBox(height: 16),
                    _buildCategoryChart(categoryCounts),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Status Distribution'),
                    const SizedBox(height: 12),
                    _buildStatusDistribution(statusCounts),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Map<String, int> _calculateBreakdown(
      List<Complaint> complaints, String Function(Complaint) attribute) {
    final Map<String, int> counts = {};
    for (var complaint in complaints) {
      final key = attribute(complaint);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style:
      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildSummaryCards(int total, double rate, double avgTime) {
    return Row(
      children: [
        Expanded(
          child: _buildAnalyticsCardSmall(
            icon: Icons.content_paste,
            value: total.toString(),
            label: 'Total\nComplaints',
            color: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAnalyticsCardSmall(
            icon: Icons.percent,
            value: '${rate.toStringAsFixed(0)}%',
            label: 'Completion\nRate',
            color: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAnalyticsCardSmall(
            icon: Icons.access_time,
            value: '${avgTime.toStringAsFixed(1)}h',
            label: 'Avg.\nResolution\nTime',
            color: const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCardSmall(
      {required IconData icon,
        required String value,
        required String label,
        required Color color}) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, int> data) {
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No data available'),
        ),
      );
    }

    final maxValue = data.values.reduce((a, b) => a > b ? a : b);
    const barWidth = 60.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.entries.map((entry) {
            final height = (entry.value / maxValue) * 150;
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${entry.value}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: barWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: barWidth,
                  child: Text(
                    entry.key,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusDistribution(Map<String, int> statusCount) {
    return Column(
      children: statusCount.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor(entry.key).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${entry.value}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(entry.key)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.yellow[700]!;
      case 'Approved':
        return Colors.purple[700]!;
      case 'Ongoing':
        return Colors.blue[700]!;
      case 'Completed':
        return Colors.green[700]!;
      case 'Rejected':
        return Colors.red[700]!;
      case 'Cancelled':
        return Colors.grey[700]!;
      default:
        return const Color(0xFF7C3AED);
    }
  }
}
