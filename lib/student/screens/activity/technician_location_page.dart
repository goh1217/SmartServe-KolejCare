import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../services/location_tracking_service.dart';
import '../../../services/eta_service.dart';
import '../../../widgets/technician_tracking_map.dart';
import 'eta_card_widget.dart';

// Type alias
typedef GoogleLatLng = gmaps.LatLng;

class TechnicianLocationPage extends StatefulWidget {
  final String? complaintId;
  final String? technicianName;
  final String? technicianPhoneNumber;
  final String? technicianImage;

  const TechnicianLocationPage({
    super.key,
    required this.complaintId,
    this.technicianName,
    this.technicianPhoneNumber,
    this.technicianImage,
  });

  @override
  State<TechnicianLocationPage> createState() => _TechnicianLocationPageState();
}

class _TechnicianLocationPageState extends State<TechnicianLocationPage> {
  late String technicianPhoneNumber;
  late String technicianName;
  late String technicianImage;
  String technicianRole = 'Technician';

  @override
  void initState() {
    super.initState();
    technicianName = widget.technicianName ?? 'Technician';
    technicianPhoneNumber = widget.technicianPhoneNumber ?? '';
    technicianImage = widget.technicianImage ?? 'https://via.placeholder.com/150';
    
    if (widget.complaintId != null) {
      _fetchTechnicianInfo();
    }
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
          'Technician Location',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Technician Info Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: NetworkImage(technicianImage),
                          onBackgroundImageError: (exception, stackTrace) {},
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                technicianName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                technicianPhoneNumber.isNotEmpty
                                    ? technicianPhoneNumber
                                    : 'Phone not available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                technicianRole,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _callTechnician,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.phone, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Call Technician',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Map and ETA Section
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                future: widget.complaintId != null
                    ? FirebaseFirestore.instance.collection('complaint').doc(widget.complaintId).get()
                    : Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snap.hasError) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Error loading complaint: ${snap.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (snap.data == null) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: const Center(
                        child: Text('Complaint not found'),
                      ),
                    );
                  }

                  final Map<String, dynamic> data = snap.data?.data() ?? {};
                  final reportStatus = (data['reportStatus'] ?? 'Ongoing').toString();
                  final location = (data['damageLocation'] ?? data['location'] ?? '').toString();
                  final assignedToRaw = (data['assignedTo'] ?? '').toString();

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ETA Card - now uses separate stateful widget
                        ETACardWidget(
                          complaintId: widget.complaintId ?? '',
                          assignedToRaw: assignedToRaw,
                        ),
                        const SizedBox(height: 16),
                        // Map Section
                        Text(
                          'Technician Location & Repair Area',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: SizedBox(
                              height: 400,
                              child: AbsorbPointer(
                                absorbing: false,
                                child: FutureBuilder<GoogleLatLng?>(
                                  future: _getRepairLocationCoordinates(data),
                                  builder: (context, locSnap) {
                                    if (!mounted) return const SizedBox.shrink();
                                    
                                    if (locSnap.connectionState == ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    if (!locSnap.hasData) {
                                      return Center(
                                        child: Text(
                                          'Unable to load map location',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      );
                                    }

                                    final repairLocation = locSnap.data!;
                                    return TechnicianTrackingMap(
                                      technicianId: (data['assignedTo'] ?? '')
                                          .toString()
                                          .split('/')
                                          .last,
                                      repairLocation: repairLocation,
                                      studentAddress: location,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, size: 16, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Scroll and pinch on map to zoom in/out',
                                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Future<GoogleLatLng?> _getRepairLocationCoordinates(Map<String, dynamic> data) async {
    try {
      var coords = data['repairLocation'];
      if (coords != null && coords is GeoPoint) {
        print('DEBUG: Found repairLocation - lat: ${coords.latitude}, lng: ${coords.longitude}');
        
        if (coords.latitude == 0 && coords.longitude == 0) {
          print('WARNING: repairLocation is (0,0) - probably uninitialized!');
        }
        
        return
GoogleLatLng(coords.latitude, coords.longitude);
      }

      coords = data['damageLocationCoordinates'];
      if (coords != null && coords is GeoPoint) {
        print('DEBUG: Found damageLocationCoordinates - lat: ${coords.latitude}, lng: ${coords.longitude}');
        
        if (coords.latitude == 0 && coords.longitude == 0) {
          print('WARNING: damageLocationCoordinates is (0,0) - probably uninitialized!');
        }
        
        return GoogleLatLng(coords.latitude, coords.longitude);
      }

      print('DEBUG: No repair location found, using default KL coordinates (3.1390, 101.6869)');
      return const GoogleLatLng(3.1390, 101.6869);
    } catch (e) {
      print("Error getting repair location: $e");
      return null;
    }
  }
}

