import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../../../widgets/technician_tracking_map.dart';
import 'phonecall.dart'; // Adjust the path as needed

// Type alias
typedef GoogleLatLng = gmaps.LatLng;


class TechnicianTrackingScreen extends StatefulWidget {
  final String technicianName;
  final String? complaintId;

  const TechnicianTrackingScreen({super.key, required this.technicianName, this.complaintId});

  @override
  State<TechnicianTrackingScreen> createState() => _TechnicianTrackingScreenState();
}

class _TechnicianTrackingScreenState extends State<TechnicianTrackingScreen> {
  String? _studentHostel;
  String? _technicianId; // Store technician ID for map tracking
  bool _loadingHostel = false;
  
  // GPS coordinates
  double? technicianLat;
  double? technicianLng;
  double? destinationLat;
  double? destinationLng;
  bool _loadingCoordinates = false;
  
  // Real-time listener
  StreamSubscription? _technicianLocationListener;
  StreamSubscription? _complaintListener;

  @override
  void initState() {
    super.initState();
    if (widget.complaintId != null) {
      _loadStudentHostel(widget.complaintId!);
      _loadCoordinates(widget.complaintId!);
      _setupRealtimeListeners(widget.complaintId!);
    }
  }

  Future<void> _loadStudentHostel(String complaintId) async {
    setState(() {
      _loadingHostel = true;
      _studentHostel = null;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('complaint').doc(complaintId).get();
      if (!doc.exists) {
        setState(() {
          _studentHostel = null;
          _loadingHostel = false;
        });
        return;
      }

      final data = doc.data() ?? {};
      dynamic reportBy = data['reportBy'] ?? data['reportedBy'] ?? data['reporter'] ?? null;
      String? studentId;

      if (reportBy == null) {
        final maybe = data['reportById'] ?? data['reportedById'] ?? data['reporterId'];
        if (maybe != null) studentId = maybe.toString();
      } else if (reportBy is DocumentReference) {
        studentId = reportBy.id;
      } else if (reportBy is String) {
        final s = reportBy as String;
        if (s.contains('/')) {
          final parts = s.split('/').where((p) => p.isNotEmpty).toList();
          if (parts.isNotEmpty) studentId = parts.last;
        } else {
          studentId = s;
        }
      }

      if (studentId != null) {
        final studentDoc = await FirebaseFirestore.instance.collection('student').doc(studentId).get();
        final sdata = studentDoc.data() ?? {};
        final hostel = (sdata['residentCollege'] ?? sdata['block'] ?? sdata['hostel'] ?? sdata['hostelLocation'] ?? sdata['room'] ?? '').toString();
        setState(() {
          _studentHostel = hostel;
          _loadingHostel = false;
        });
        return;
      }
    } catch (e) {
      print('Error loading hostel: $e');
    }

    setState(() {
      _studentHostel = null;
      _loadingHostel = false;
    });
  }

  Future<void> _loadCoordinates(String complaintId) async {
    setState(() {
      _loadingCoordinates = true;
    });

    try {
      // Load complaint to get repairLocation (destination)
      final complaintDoc = await FirebaseFirestore.instance.collection('complaint').doc(complaintId).get();
      if (complaintDoc.exists) {
        final data = complaintDoc.data() ?? {};
        
        // Get repair location (destination)
        final repairLocation = data['repairLocation'];
        if (repairLocation != null && repairLocation is GeoPoint) {
          setState(() {
            destinationLat = repairLocation.latitude;
            destinationLng = repairLocation.longitude;
          });
          print('DEBUG: Loaded destination - lat: $destinationLat, lng: $destinationLng');
        }
        
        // Get assigned technician ID to look up current location
        final assignedToRaw = (data['assignedTo'] ?? '').toString();
        print('DEBUG _loadCoordinates: assignedToRaw = "$assignedToRaw"');
        if (assignedToRaw.isNotEmpty) {
          final parts = assignedToRaw.split('/').where((s) => s.isNotEmpty).toList();
          print('DEBUG _loadCoordinates: parts = $parts');
          if (parts.isNotEmpty) {
            final techDocId = parts.last;
            print('DEBUG _loadCoordinates: Setting technicianId to "$techDocId"');
            setState(() {
              _technicianId = techDocId; // Store technician ID
            });
            print('DEBUG _loadCoordinates: After setState, _technicianId=$_technicianId');
            
            // Load current technician location
            final techDoc = await FirebaseFirestore.instance.collection('technician').doc(techDocId).get();
            if (techDoc.exists) {
              final techData = techDoc.data() ?? {};
              final currentLocation = techData['currentLocation'];
              if (currentLocation != null && currentLocation is GeoPoint) {
                setState(() {
                  technicianLat = currentLocation.latitude;
                  technicianLng = currentLocation.longitude;
                });
                print('DEBUG: Loaded technician location - lat: $technicianLat, lng: $technicianLng');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error loading coordinates: $e');
    }

    setState(() {
      _loadingCoordinates = false;
    });
  }

  void _setupRealtimeListeners(String complaintId) {
    try {
      // Listen to complaint changes (repairLocation)
      _complaintListener = FirebaseFirestore.instance
          .collection('complaint')
          .doc(complaintId)
          .snapshots()
          .listen((doc) {
        try {
          if (doc.exists) {
            final data = doc.data() ?? {};
            final repairLocation = data['repairLocation'];
            if (repairLocation != null && repairLocation is GeoPoint) {
              setState(() {
                destinationLat = repairLocation.latitude;
                destinationLng = repairLocation.longitude;
              });
              print('DEBUG setupRealtimeListeners: Loaded destination - lat: $destinationLat, lng: $destinationLng');
            }
            
            // Also listen for technician changes
            final assignedToRaw = (data['assignedTo'] ?? '').toString();
            print('DEBUG setupRealtimeListeners: assignedToRaw = $assignedToRaw');
            if (assignedToRaw.isNotEmpty) {
              final parts = assignedToRaw.split('/').where((s) => s.isNotEmpty).toList();
              if (parts.isNotEmpty) {
                final techDocId = parts.last;
                setState(() {
                  _technicianId = techDocId; // Store technician ID
                });
                print('DEBUG setupRealtimeListeners: Setting up listener for technician: $techDocId');
                _listenToTechnicianLocation(techDocId);
              }
            }
          }
        } catch (e) {
          print('Error in complaint listener callback: $e');
        }
      });
    } catch (e) {
      print('Error setting up complaint listener: $e');
    }
  }

  void _listenToTechnicianLocation(String techDocId) {
    try {
      print('DEBUG _listenToTechnicianLocation: Starting listener for techDocId=$techDocId');
      _technicianLocationListener?.cancel();
      _technicianLocationListener = FirebaseFirestore.instance
          .collection('technician')
          .doc(techDocId)
          .snapshots()
          .listen(
        (doc) {
          try {
            print('DEBUG _listenToTechnicianLocation: Received snapshot for $techDocId');
            if (doc.exists) {
              final data = doc.data();
              print('DEBUG _listenToTechnicianLocation: Document data type = ${data.runtimeType}');
              
              if (data != null) {
                print('DEBUG _listenToTechnicianLocation: Data keys = ${data.keys}');
                final currentLocation = data['currentLocation'];
                print('DEBUG _listenToTechnicianLocation: currentLocation type = ${currentLocation.runtimeType}');
                
                if (currentLocation != null) {
                  if (currentLocation is GeoPoint) {
                    print('DEBUG _listenToTechnicianLocation: currentLocation is GeoPoint, lat=${currentLocation.latitude}, lng=${currentLocation.longitude}');
                    setState(() {
                      technicianLat = currentLocation.latitude;
                      technicianLng = currentLocation.longitude;
                    });
                    print('DEBUG: Updated technician location - lat: $technicianLat, lng: $technicianLng');
                  } else {
                    print('DEBUG _listenToTechnicianLocation: currentLocation is NOT GeoPoint, it is ${currentLocation.runtimeType}');
                  }
                }
              }
            }
          } catch (e) {
            print('Error in technician location snapshot callback: $e');
          }
        },
        onError: (error) {
          print('ERROR in technician location stream: $error');
        },
      );
    } catch (e) {
      print('Error setting up technician location listener: $e');
    }
  }

  @override
  void dispose() {
    _technicianLocationListener?.cancel();
    _complaintListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final techId = _getTechnicianIdFromComplaint();
    final hasRepairLocation = destinationLat != null && destinationLng != null;
    
    print('DEBUG BUILD: techId=$techId, hasRepairLocation=$hasRepairLocation');
    print('DEBUG BUILD: technicianLat=$technicianLat, technicianLng=$technicianLng');
    print('DEBUG BUILD: destinationLat=$destinationLat, destinationLng=$destinationLng');
    
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Stack(
        children: [
          // Map area using TechnicianTrackingMap widget
          Positioned.fill(
            child: _loadingCoordinates
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : (techId.isNotEmpty && hasRepairLocation)
                    ? TechnicianTrackingMap(
                        technicianId: techId,
                        repairLocation: GoogleLatLng(destinationLat!, destinationLng!),
                        studentAddress: _studentHostel ?? 'Unknown',
                      )
                    : Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Loading location data...\n(techId: $techId, hasRepair: $hasRepairLocation)',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
          ),

          // Top App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Technician Tracking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Details Card - Compact Version
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Technician Info Row - Compact
                      Row(
                        children: [
                          // Avatar - Smaller
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.network(
                              'assets/male.jpg',
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 44,
                                  height: 44,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, size: 24),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Name and Title - Compact
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.technicianName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Technician',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Phone Button - Smaller
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B46C1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PhoneCallScreen(
                                      technicianName: widget.technicianName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Compact Location Info - Single Row
                      Row(
                        children: [
                          Expanded(
                            child: _CompactInfoRow(
                              icon: Icons.location_on,
                              iconColor: const Color(0xFF6B46C1),
                              title: 'Hostel',
                              subtitle: _loadingHostel
                                  ? 'Loading...'
                                  : (_studentHostel?.isNotEmpty == true ? _studentHostel!.split(',')[0] : 'Unknown'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CompactInfoRow(
                              icon: Icons.location_pin,
                              iconColor: const Color(0xFFFF6B6B),
                              title: 'Destination',
                              subtitle: destinationLat != null && destinationLng != null
                                  ? '${destinationLat!.toStringAsFixed(3)}°'
                                  : 'Loading...',
                            ),
                          ),
                        ],
                      ),
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

  String _getTechnicianIdFromComplaint() {
    print('DEBUG _getTechnicianIdFromComplaint: _technicianId=$_technicianId');
    return _technicianId ?? '';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact version of InfoRow for smaller displays
class _CompactInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _CompactInfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}