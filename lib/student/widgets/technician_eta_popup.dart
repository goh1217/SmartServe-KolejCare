import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../services/location_tracking_service.dart';
import '../../services/eta_service.dart';
import '../screens/activity/technician_location_page.dart';

/// Popup card widget that shows technician ETA (similar to Shopee/Grab/Foodpanda)
/// Only displays when task status is 'ongoing'
class TechnicianETAPopup extends StatefulWidget {
  final String complaintId;
  final VoidCallback? onClose;

  const TechnicianETAPopup({
    super.key,
    required this.complaintId,
    this.onClose,
  });

  @override
  State<TechnicianETAPopup> createState() => _TechnicianETAPopupState();
}

class _TechnicianETAPopupState extends State<TechnicianETAPopup> {
  Timer? _etaUpdateTimer;
  Timer? _countdownTimer;
  String _etaText = 'Calculating...';
  String _technicianName = 'Technician';
  String _technicianImage = '';
  bool _isLoading = true;
  bool _hasArrived = false;
  int _minutesRemaining = 0;
  DateTime? _estimatedArrivalTime;
  StreamSubscription? _complaintSubscription;

  @override
  void initState() {
    super.initState();
    _initializePopup();
  }

  @override
  void dispose() {
    _etaUpdateTimer?.cancel();
    _countdownTimer?.cancel();
    _complaintSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializePopup() async {
    // Calculate ETA immediately
    await _calculateAndUpdateETA();

    // Set up real-time listener for complaint status changes
    _complaintSubscription = FirebaseFirestore.instance
        .collection('complaint')
        .doc(widget.complaintId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final data = snapshot.data() ?? {};
      final arrivedAt = data['arrivedAt'];

      if (arrivedAt != null) {
        setState(() {
          _hasArrived = true;
          _updateArrivalText(arrivedAt);
        });
      }
    });

    // Update ETA every 30 seconds (less frequent than location page)
    _etaUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted && !_hasArrived) {
          _calculateAndUpdateETA();
        }
      },
    );

    // Update countdown every minute
    _countdownTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted && !_hasArrived && _estimatedArrivalTime != null) {
          _updateCountdown();
        }
      },
    );
  }

  void _updateCountdown() {
    if (_estimatedArrivalTime == null) return;

    final now = DateTime.now();
    final difference = _estimatedArrivalTime!.difference(now);

    if (mounted) {
      setState(() {
        _minutesRemaining = difference.inMinutes.clamp(0, 999);
      });
    }
  }

  void _updateArrivalText(dynamic arrivedAt) {
    try {
      String arrivedText = 'Arrived';
      if (arrivedAt is Timestamp) {
        arrivedText =
            'Arrived at ${DateFormat('hh:mm a').format(arrivedAt.toDate().toLocal())}';
      } else if (arrivedAt is String) {
        final parsed = DateTime.tryParse(arrivedAt);
        if (parsed != null) {
          arrivedText =
              'Arrived at ${DateFormat('hh:mm a').format(parsed.toLocal())}';
        }
      } else if (arrivedAt is DateTime) {
        arrivedText =
            'Arrived at ${DateFormat('hh:mm a').format(arrivedAt.toLocal())}';
      }

      if (mounted) {
        setState(() {
          _etaText = arrivedText;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error formatting arrival time: $e');
    }
  }

  Future<void> _calculateAndUpdateETA() async {
    if (!mounted) return;

    try {
      // Get complaint data
      final complaintDoc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.complaintId)
          .get();

      if (!complaintDoc.exists) {
        if (mounted) {
          setState(() {
            _etaText = 'Report not found';
            _isLoading = false;
          });
        }
        return;
      }

      final data = complaintDoc.data() ?? {};

      // Check if technician has arrived
      final arrivedAt = data['arrivedAt'];
      if (arrivedAt != null) {
        _updateArrivalText(arrivedAt);
        return;
      }

      // Get assigned technician info
      final assignedToRaw = (data['assignedTo'] ?? '').toString();
      if (assignedToRaw.isEmpty) {
        if (mounted) {
          setState(() {
            _etaText = 'No technician assigned';
            _isLoading = false;
          });
        }
        return;
      }

      // Get technician's current location
      final techId = assignedToRaw.split('/').last;
      final techLocation =
          await LocationTrackingService().getTechnicianCurrentLocation(techId);

      // Get technician info for display
      final techDoc =
          await FirebaseFirestore.instance.collection('technician').doc(techId).get();
      if (techDoc.exists) {
        final techData = techDoc.data() ?? {};
        if (mounted) {
          setState(() {
            _technicianName =
                (techData['technicianName'] ?? 'Technician').toString();
            _technicianImage = (techData['profilePic'] ?? '').toString();
          });
        }
      }

      if (techLocation == null) {
        if (mounted) {
          final defaultArrival = DateTime.now().add(const Duration(minutes: 30));
          final minutesLeft = defaultArrival.difference(DateTime.now()).inMinutes;
          setState(() {
            _estimatedArrivalTime = defaultArrival;
            _minutesRemaining = minutesLeft;
            _etaText =
                'Arrive at ${DateFormat('hh:mm a').format(defaultArrival)}';
            _isLoading = false;
          });
        }
        return;
      }

      // Get repair location coordinates
      var repairCoords = data['repairLocation'];
      double? repairLat, repairLng;

      if (repairCoords is GeoPoint) {
        repairLat = repairCoords.latitude;
        repairLng = repairCoords.longitude;
      }

      if (repairLat == null || repairLng == null) {
        if (mounted) {
          final defaultArrival = DateTime.now().add(const Duration(minutes: 30));
          final minutesLeft = defaultArrival.difference(DateTime.now()).inMinutes;
          setState(() {
            _estimatedArrivalTime = defaultArrival;
            _minutesRemaining = minutesLeft;
            _etaText =
                'Arrive at ${DateFormat('hh:mm a').format(defaultArrival)}';
            _isLoading = false;
          });
        }
        return;
      }

      // Calculate ETA using Directions API
      final eta = await ETAService().calculateETAMinutes(
        originLat: techLocation.latitude,
        originLng: techLocation.longitude,
        destinationLat: repairLat,
        destinationLng: repairLng,
      );

      // Calculate arrival time
      final arrivalTime = DateTime.now().add(Duration(minutes: eta));
      final minutesLeft = eta.clamp(0, 999);

      if (mounted) {
        setState(() {
          _estimatedArrivalTime = arrivalTime;
          _minutesRemaining = minutesLeft;
          _etaText = 'Arrive at ${DateFormat('hh:mm a').format(arrivalTime)}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error calculating ETA: $e');
      if (mounted) {
        final defaultArrival = DateTime.now().add(const Duration(minutes: 30));
        final minutesLeft = 30;
        setState(() {
          _estimatedArrivalTime = defaultArrival;
          _minutesRemaining = minutesLeft;
          _etaText =
              'Arrive at ${DateFormat('hh:mm a').format(defaultArrival)}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to technician location page when tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TechnicianLocationPage(complaintId: widget.complaintId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _hasArrived
                  ? Colors.green.shade400
                  : Colors.deepPurple.shade400,
              _hasArrived
                  ? Colors.green.shade600
                  : Colors.deepPurple.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_hasArrived ? Colors.green : Colors.deepPurple)
                  .withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasArrived ? 'Technician Arrived' : 'Technician On The Way',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _technicianName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    widget.onClose?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ETA Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Arrival',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _isLoading
                          ? const SizedBox(
                              width: 120,
                              child: LinearProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                minHeight: 3,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _etaText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Countdown timer
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 14,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _minutesRemaining <= 0
                                            ? 'Arriving now'
                                            : _minutesRemaining == 1
                                                ? '1 minute left'
                                                : '$_minutesRemaining minutes left',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                  // Icon indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _hasArrived ? Icons.check_circle : Icons.location_on,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Tap to view location hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app,
                  color: Colors.white.withOpacity(0.7),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tap to view technician location',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
