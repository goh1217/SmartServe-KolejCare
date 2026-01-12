import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class WaitingApprovalScreen extends StatefulWidget {
  final String? complaintId;
  final String reportStatus;
  final String damageCategory;
  final String damageLocation;
  final String inventoryDamage;
  final String inventoryDamageTitle;
  final String reportedOn;

  const WaitingApprovalScreen({
    super.key,
    this.complaintId,
    required this.reportStatus,
    required this.damageCategory,
    required this.damageLocation,
    required this.inventoryDamage,
    required this.inventoryDamageTitle,
    required this.reportedOn,
  });

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen> {
  String? cantCompleteReason;
  List<String> cantCompleteProofList = [];
  int currentProofIndex = 0;
  List<String> damagePicList = [];
  int currentDamagePhotoIndex = 0;
  String loadedReportStatus = '';
  String loadedDamageCategory = '';
  String loadedDamageLocation = '';
  String loadedInventoryDamage = '';
  String loadedInventoryDamageTitle = '';
  String loadedReportedOn = '';

  @override
  void initState() {
    super.initState();
    if (widget.complaintId != null) {
      _loadComplaintData();
    }
  }

  Future<void> _loadComplaintData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.complaintId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          loadedReportStatus = data['reportStatus'] ?? widget.reportStatus;
          loadedDamageCategory = data['damageCategory'] ?? widget.damageCategory;
          loadedDamageLocation = data['damageLocation'] ?? widget.damageLocation;
          loadedInventoryDamage = data['inventoryDamage'] ?? widget.inventoryDamage;
          loadedInventoryDamageTitle = data['inventoryDamageTitle'] ?? widget.inventoryDamageTitle;
          cantCompleteReason = data['reasonCantComplete'];
          
          // Handle reasonCantCompleteProof as both string and list
          if (data['reasonCantCompleteProof'] != null) {
            if (data['reasonCantCompleteProof'] is List) {
              cantCompleteProofList = List<String>.from(data['reasonCantCompleteProof'] as List);
            } else if (data['reasonCantCompleteProof'] is String) {
              cantCompleteProofList = [data['reasonCantCompleteProof'] as String];
            }
            currentProofIndex = 0;
          }
          
          // Handle damagePic as a list (max 3)
          if (data['damagePic'] != null && data['damagePic'] is List) {
            damagePicList = List<String>.from(data['damagePic'] as List);
            // Limit to max 3 pictures
            if (damagePicList.length > 3) {
              damagePicList = damagePicList.sublist(0, 3);
            }
            currentDamagePhotoIndex = 0;
          }
          
          // Format reported date
          if (data['reportedDate'] != null) {
            Timestamp ts = data['reportedDate'] as Timestamp;
            DateTime dt = ts.toDate();
            loadedReportedOn = '${dt.day} ${_monthName(dt.month)} ${dt.year}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'AM' : 'PM'}';
          } else {
            loadedReportedOn = widget.reportedOn;
          }
        });
      }
    } catch (e) {
      print('Error loading complaint data: $e');
    }
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
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
                _buildDetailItem('Report Status', loadedReportStatus.isNotEmpty ? loadedReportStatus : widget.reportStatus, isFirst: true),
                const Divider(height: 1),
                _buildDetailItem('Damage Category', loadedDamageCategory.isNotEmpty ? loadedDamageCategory : widget.damageCategory),
                const Divider(height: 1),
                _buildDetailItem('Damage Location', loadedDamageLocation.isNotEmpty ? loadedDamageLocation : widget.damageLocation),
                const Divider(height: 1),
                _buildDetailItem('Damage Title', loadedInventoryDamageTitle.isNotEmpty ? loadedInventoryDamageTitle : widget.inventoryDamageTitle),
                const Divider(height: 1),
                _buildDetailItem('Inventory Damage', loadedInventoryDamage.isNotEmpty ? loadedInventoryDamage : widget.inventoryDamage),
                const Divider(height: 1),
                _buildDetailItem('Reported On', loadedReportedOn.isNotEmpty ? loadedReportedOn : widget.reportedOn, isLast: false),
                if (damagePicList.isNotEmpty) ...[
                  const Divider(height: 1),
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Damage Photo${damagePicList.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (damagePicList.length == 1)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              damagePicList[0],
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
                                        currentDamagePhotoIndex = (currentDamagePhotoIndex - 1 + damagePicList.length) % damagePicList.length;
                                      });
                                    },
                                  ),
                                  // Image display
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        damagePicList[currentDamagePhotoIndex],
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
                                        currentDamagePhotoIndex = (currentDamagePhotoIndex + 1) % damagePicList.length;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              // Image counter
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${currentDamagePhotoIndex + 1} / ${damagePicList.length}',
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
                if (cantCompleteProofList.isNotEmpty) ...[
                  const Divider(height: 1),
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Can\'t Complete Proof Photo${cantCompleteProofList.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (cantCompleteReason != null && cantCompleteReason!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              cantCompleteReason!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (cantCompleteProofList.length == 1)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              cantCompleteProofList[0],
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
                                        currentProofIndex = (currentProofIndex - 1 + cantCompleteProofList.length) % cantCompleteProofList.length;
                                      });
                                    },
                                  ),
                                  // Image display
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        cantCompleteProofList[currentProofIndex],
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
                                        currentProofIndex = (currentProofIndex + 1) % cantCompleteProofList.length;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              // Image counter
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${currentProofIndex + 1} / ${cantCompleteProofList.length}',
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