import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../services/location_tracking_service.dart';
import '../../../services/eta_service.dart';

/// Standalone ETA card widget that updates independently every 10 seconds
class ETACardWidget extends StatefulWidget {
  final String complaintId;
  final String assignedToRaw;

  const ETACardWidget({
    super.key,
    required this.complaintId,
    required this.assignedToRaw,
  });

  @override
  State<ETACardWidget> createState() => _ETACardWidgetState();
}

class _ETACardWidgetState extends State<ETACardWidget> {
  Timer? _etaUpdateTimer;
  String _etaText = 'Arrive at --:-- --';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Calculate ETA immediately
    _calculateAndUpdateETA();
    // Then update every 10 seconds
    _etaUpdateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted) {
          _calculateAndUpdateETA();
        }
      },
    );
  }

  @override
  void dispose() {
    _etaUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _calculateAndUpdateETA() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get complaint data
      final complaintDoc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.complaintId)
          .get();

      if (!complaintDoc.exists) {
        setState(() {
          _etaText = 'Arrive at --:-- --';
          _isLoading = false;
        });
        return;
      }

      final data = complaintDoc.data() as Map<String, dynamic>;
      
      // Check if technician has arrived
      final arrivedAt = data['arrivedAt'];
      final reportStatus = (data['reportStatus'] ?? 'Ongoing').toString();
      
      if (arrivedAt != null && reportStatus.toLowerCase() == 'ongoing') {
        // Technician has arrived, display arrival time
        String arrivedText = 'Arrived at --:-- --';
        try {
          if (arrivedAt is Timestamp) {
            arrivedText = 'Arrived at ${DateFormat('hh:mm a').format(arrivedAt.toDate().toLocal())}';
          } else if (arrivedAt is String) {
            final parsed = DateTime.tryParse(arrivedAt);
            if (parsed != null) {
              arrivedText = 'Arrived at ${DateFormat('hh:mm a').format(parsed.toLocal())}';
            }
          } else if (arrivedAt is DateTime) {
            arrivedText = 'Arrived at ${DateFormat('hh:mm a').format(arrivedAt.toLocal())}';
          }
        } catch (e) {
          print('Error formatting arrivedAt: $e');
        }
        
        if (mounted) {
          setState(() {
            _etaText = arrivedText;
            _isLoading = false;
          });
        }
        return;
      }

      // Get technician's current location
      final techId = widget.assignedToRaw.split('/').last;
      final techLocation =
          await LocationTrackingService().getTechnicianCurrentLocation(techId);

      if (techLocation == null) {
        final defaultArrival = DateTime.now().add(const Duration(minutes: 30));
        setState(() {
          _etaText =
              'Arrive at ${DateFormat('hh:mm a').format(defaultArrival)}';
          _isLoading = false;
        });
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
        final defaultArrival = DateTime.now().add(const Duration(minutes: 30));
        setState(() {
          _etaText =
              'Arrive at ${DateFormat('hh:mm a').format(defaultArrival)}';
          _isLoading = false;
        });
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

      if (mounted) {
        setState(() {
          _etaText = 'Arrive at ${DateFormat('hh:mm a').format(arrivalTime)}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error calculating ETA: $e');
      if (mounted) {
        final defaultArrival = DateTime.now().add(const Duration(minutes: 30));
        setState(() {
          _etaText =
              'Arrive at ${DateFormat('hh:mm a').format(defaultArrival)}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArrived = _etaText.startsWith('Arrived at');
    final bgColor = isArrived ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1);
    final borderColor = isArrived ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3);
    final iconColor = isArrived ? Colors.green[700] : Colors.orange[700];
    final textColor = isArrived ? Colors.green[700] : Colors.orange[700];
    final iconData = isArrived ? Icons.check_circle : Icons.schedule;
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(iconData, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _etaText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          if (_isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor!),
              ),
            ),
        ],
      ),
    );
  }
}
