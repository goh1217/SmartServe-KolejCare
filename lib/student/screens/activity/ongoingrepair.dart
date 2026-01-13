import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/location_tracking_service.dart';
import '../../../services/eta_service.dart';
import 'technician_location_page.dart';

class OngoingRepairScreen extends StatefulWidget {
  final String? complaintId;

  const OngoingRepairScreen({super.key, this.complaintId});

  @override
  State<OngoingRepairScreen> createState() => _OngoingRepairScreenState();
}

class _OngoingRepairScreenState extends State<OngoingRepairScreen> {
  String technicianPhoneNumber = '';
  String technicianName = '';
  String technicianImage = 'https://via.placeholder.com/150';
  String technicianRole = 'Technician';
  List<String> damagePicList = [];
  int currentDamagePhotoIndex = 0;
  
  // Cache for ETA calculations to avoid repeated API calls
  final Map<String, int> _etaCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.complaintId != null) {
      _fetchTechnicianInfo();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchTechnicianInfo() async {
    try {
      final complaintDoc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.complaintId)
          .get();

      if (complaintDoc.exists) {
        final data = complaintDoc.data() as Map<String, dynamic>;
        final assignedToRaw = (data['assignedTo'] ?? '').toString();

        if (assignedToRaw.isNotEmpty) {
          final parts = assignedToRaw.split('/').where((s) => s.isNotEmpty).toList();
          if (parts.isNotEmpty) {
            final techId = parts.last;
            final techDoc = await FirebaseFirestore.instance
                .collection('technician')
                .doc(techId)
                .get();

            if (techDoc.exists) {
              final techData = techDoc.data() as Map<String, dynamic>;
              setState(() {
                technicianName = techData['technicianName'] ?? techData['name'] ?? 'Technician';
                technicianPhoneNumber = techData['phoneNo'] ?? 
                                       techData['phoneNumber'] ?? 
                                       techData['phone'] ?? '';
                if (techData['photoUrl'] != null) {
                  technicianImage = techData['photoUrl'] as String;
                }
              });
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching technician info: $e");
    }
  }

  Future<void> _callTechnician() async {
    if (technicianPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Technician phone number not available')),
      );
      return;
    }

    final sanitizedPhoneNumber = technicianPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (sanitizedPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone number format')),
      );
      return;
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: sanitizedPhoneNumber,
    );

    try {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print("Error launching phone call: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: true,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                  future: widget.complaintId != null
                      ? FirebaseFirestore.instance.collection('complaint').doc(widget.complaintId).get()
                      : Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final Map<String, dynamic> data = snap.data?.data() ?? {};
                    final id = widget.complaintId ?? data['complaintID'] ?? snap.data?.id ?? '—';

                    final serviceCategory = (data['damageCategory'] ?? data['category'] ?? '').toString();
                    final location = (data['damageLocation'] ?? data['location'] ?? '').toString();
                    final issue = (data['inventoryDamage'] ?? data['description'] ?? data['damageDesc'] ?? '').toString();
                    final reportStatus = (data['reportStatus'] ?? 'Ongoing').toString();
                    final String assignedToRaw = (data['assignedTo'] ?? '').toString();
                    final arrivedAt = data['arrivedAt'];
                    
                    // Calculate ETA using Google Directions API with real technician location
                    Future<int> calculateETA() async {
                      final cacheKey = widget.complaintId ?? '';
                      if (_etaCache.containsKey(cacheKey)) {
                        return _etaCache[cacheKey]!;
                      }

                      try {
                        // Get technician's current location
                        final techId = assignedToRaw.split('/').last;
                        final techLocation = await LocationTrackingService().getTechnicianCurrentLocation(techId);

                        if (techLocation == null) {
                          print('Technician location not available, using fallback');
                          return 30;
                        }

                        // Get repair location coordinates
                        var repairCoords = data['repairLocation'];
                        double? repairLat, repairLng;

                        if (repairCoords is GeoPoint) {
                          repairLat = repairCoords.latitude;
                          repairLng = repairCoords.longitude;
                        }

                        if (repairLat == null || repairLng == null) {
                          print('Repair location not available, using fallback');
                          return 30;
                        }

                        // Calculate ETA using Directions API
                        final eta = await ETAService().calculateETAMinutes(
                          originLat: techLocation.latitude,
                          originLng: techLocation.longitude,
                          destinationLat: repairLat,
                          destinationLng: repairLng,
                        );

                        _etaCache[cacheKey] = eta;
                        return eta;
                      } catch (e) {
                        print('Error calculating ETA: $e');
                        return 30;
                      }
                    }
                    
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
                    
                    // Extract damage photos from data
                    List<String> damagePics = [];
                    if (data['damagePic'] != null && data['damagePic'] is List) {
                      damagePics = List<String>.from(data['damagePic'] as List);
                      // Limit to max 3 pictures
                      if (damagePics.length > 3) {
                        damagePics = damagePics.sublist(0, 3);
                      }
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailItem('Report ID', id.toString(), isFirst: true),
                          const Divider(height: 1),
                          _buildDetailItem(
                            'Repair Status',
                            '',
                            trailing: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  reportStatus,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                arrivedAt != null && reportStatus.toLowerCase() == 'ongoing'
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Colors.green[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Arrived at ${_formatArrivedAtTime(arrivedAt)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.green[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : FutureBuilder<int>(
                                        future: calculateETA(),
                                        builder: (context, etaSnap) {
                                          final eta = etaSnap.data ?? 30;
                                          final arrivalTime = DateTime.now().add(Duration(minutes: eta));
                                          final arrivalText = DateFormat('hh:mm a').format(arrivalTime);
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.schedule,
                                                  size: 14,
                                                  color: Colors.orange[700],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Arrive at $arrivalText',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.orange[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
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
                          _buildDetailItem('Damage Location', location),
                          const Divider(height: 1),
                          _buildDetailItem('Issue Description', issue),
                          const Divider(height: 1),
                          if (damagePics.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Damage Photo${damagePics.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (damagePics.length == 1)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        damagePics[0],
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
                                                  currentDamagePhotoIndex = (currentDamagePhotoIndex - 1 + damagePics.length) % damagePics.length;
                                                });
                                              },
                                            ),
                                            // Image display
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.network(
                                                  damagePics[currentDamagePhotoIndex],
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
                                                  currentDamagePhotoIndex = (currentDamagePhotoIndex + 1) % damagePics.length;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        // Image counter
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            '${currentDamagePhotoIndex + 1} / ${damagePics.length}',
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
                            const Divider(height: 1),
                          ],
                          _buildDetailItem('Reported On', reportedText, isLast: false),
                          const Divider(height: 1),
                          // View Technician Location Button
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TechnicianLocationPage(
                                      complaintId: widget.complaintId,
                                      technicianName: technicianName,
                                      technicianPhoneNumber: technicianPhoneNumber,
                                      technicianImage: technicianImage,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5F33E1),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF5F33E1).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.location_on, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'View Technician Location',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
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

  String _formatArrivedAtTime(dynamic arrivedAt) {
    try {
      if (arrivedAt is Timestamp) {
        return DateFormat('hh:mm a').format(arrivedAt.toDate().toLocal());
      } else if (arrivedAt is String) {
        final parsed = DateTime.tryParse(arrivedAt);
        if (parsed != null) {
          return DateFormat('hh:mm a').format(parsed.toLocal());
        }
      } else if (arrivedAt is DateTime) {
        return DateFormat('hh:mm a').format(arrivedAt.toLocal());
      }
    } catch (e) {
      print('Error formatting arrivedAt time: $e');
    }
    return 'Unknown';
  }
}