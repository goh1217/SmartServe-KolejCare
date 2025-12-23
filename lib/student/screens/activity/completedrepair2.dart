import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompletedRepair2Screen extends StatefulWidget {
  final String reportId;
  final String status;
  final String completedDate;
  final String assignedTechnician;
  final String damageCategory;
  final String damageLocation;
  final String inventoryDamage;
  final String inventoryDamageTitle;

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
  });

  @override
  State<CompletedRepair2Screen> createState() => _CompletedRepair2ScreenState();
}

class _CompletedRepair2ScreenState extends State<CompletedRepair2Screen> {
  List<String> proofImages = [];
  int currentProofImageIndex = 0;
  String reportedOnFormatted = '';

  @override
  void initState() {
    super.initState();
    _loadProofImagesAndReportedDate();
  }

  Future<void> _loadProofImagesAndReportedDate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.reportId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          // Load proof images
          if (data['proofPic'] != null) {
            if (data['proofPic'] is List) {
              proofImages = List<String>.from(data['proofPic'] as List);
            } else if (data['proofPic'] is String) {
              proofImages = [data['proofPic'] as String];
            }
            currentProofImageIndex = 0;
          }
          
          // Format reported date from Firestore
          if (data['reportedDate'] != null) {
            Timestamp ts = data['reportedDate'] as Timestamp;
            DateTime dt = ts.toDate();
            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            final ampm = dt.hour < 12 ? 'AM' : 'PM';
            final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
            reportedOnFormatted = '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
          }
        });
      }
    } catch (e) {
      print('Error loading data: $e');
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
                      _buildDetailItem('Report ID', widget.reportId, isFirst: true),
                      const Divider(height: 1),
                      _buildDetailItem('Repair Status', widget.status),
                      const Divider(height: 1),
                      _buildDetailItem('Completed On', widget.completedDate),
                      const Divider(height: 1),
                      _buildDetailItem('Assigned Technician', widget.assignedTechnician),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Category', widget.damageCategory),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Location', widget.damageLocation),
                      const Divider(height: 1),
                      _buildDetailItem('Damage Title', widget.inventoryDamageTitle),
                      const Divider(height: 1),
                      _buildDetailItem('Inventory Damage', widget.inventoryDamage),
                      const Divider(height: 1),
                      _buildDetailItem('Reported On', reportedOnFormatted, isLast: false),
                      
                      // Proof images section
                      if (proofImages.isNotEmpty) ...[
                        const Divider(height: 1),
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Completion Proof Photo${proofImages.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (proofImages.length == 1)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    proofImages[0],
                                    width: double.infinity,
                                    height: 250,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: double.infinity,
                                        height: 250,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.image, size: 50),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Left arrow button
                                        IconButton(
                                          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              currentProofImageIndex = (currentProofImageIndex - 1 + proofImages.length) % proofImages.length;
                                            });
                                          },
                                        ),
                                        // Image display
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              proofImages[currentProofImageIndex],
                                              width: double.infinity,
                                              height: 250,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: double.infinity,
                                                  height: 250,
                                                  color: Colors.grey.shade300,
                                                  child: const Icon(Icons.image, size: 50),
                                                );
                                              },
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                        : null,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        // Right arrow button
                                        IconButton(
                                          icon: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              currentProofImageIndex = (currentProofImageIndex + 1) % proofImages.length;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    // Image counter
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '${currentProofImageIndex + 1} / ${proofImages.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
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