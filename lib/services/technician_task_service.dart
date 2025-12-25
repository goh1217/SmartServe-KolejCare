import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/location_model.dart';
import 'gps_service.dart';

/// Service for managing technician task operations
class TechnicianTaskService {
  static final TechnicianTaskService _instance =
      TechnicianTaskService._internal();

  factory TechnicianTaskService() {
    return _instance;
  }

  TechnicianTaskService._internal();

  /// Start a task by enabling GPS tracking and updating Firestore
  Future<void> startTask(
    String complaintId,
    String technicianUserId,
  ) async {
    try {
      print('DEBUG startTask: Starting task for technicianUserId=$technicianUserId, complaintId=$complaintId');
      
      // First, find the technician document by querying the uid field
      final technicianSnapshot = await FirebaseFirestore.instance
          .collection('technician')
          .where('uid', isEqualTo: technicianUserId)
          .limit(1)
          .get();

      if (technicianSnapshot.docs.isEmpty) {
        throw Exception('Technician document not found for user ID: $technicianUserId');
      }

      final technicianDocId = technicianSnapshot.docs.first.id;
      print('DEBUG startTask: Found technician document ID: $technicianDocId');
      
      final gpsService = GPSService();
      
      // Initialize currentLocation in Firestore
      Map<String, dynamic> technicianUpdate = {
        'currentTaskId': complaintId,
        'isOnTask': true,
        'taskStartedAt': Timestamp.now(),
      };

      print('DEBUG startTask: Initial update data: $technicianUpdate');

      // Try to get initial location
      try {
        final initialLocation = await gpsService.getCurrentLocation();
        if (initialLocation != null) {
          // IMPORTANT: GeoPoint(latitude, longitude) - NOT (lng, lat)!
          final geopoint = GeoPoint(initialLocation.latitude, initialLocation.longitude);
          print('DEBUG startTask: Creating GeoPoint(lat=${initialLocation.latitude}, lng=${initialLocation.longitude})');
          
          technicianUpdate['currentLocation'] = geopoint;
          technicianUpdate['locationUpdatedAt'] = Timestamp.now();
          print('DEBUG startTask: Initial location obtained: ${initialLocation.latitude}, ${initialLocation.longitude}');
        }
      } catch (e) {
        print('Warning: Could not get initial location: $e');
        // Continue even if location fetch fails - set a placeholder
        // NOTE: This is Latitude 0, Longitude 0 (Prime Meridian)
        technicianUpdate['currentLocation'] = const GeoPoint(0, 0);
        technicianUpdate['locationUpdatedAt'] = Timestamp.now();
        print('DEBUG startTask: Using placeholder currentLocation(0,0) due to GPS permission issue');
      }

      print('DEBUG startTask: Final update data before Firestore write: $technicianUpdate');

      // Update the existing technician document
      final docRef = FirebaseFirestore.instance
          .collection('technician')
          .doc(technicianDocId);
      
      print('DEBUG startTask: Writing to Firestore at path: technician/$technicianDocId');
      
      await docRef.update(technicianUpdate);

      print('DEBUG startTask: Successfully updated technician document to Firestore');
      
      // Verify the write by reading back
      final verifyDoc = await docRef.get();
      if (verifyDoc.exists) {
        print('DEBUG startTask: Verified - Firestore document exists with data: ${verifyDoc.data()}');
      }

      // Update complaint status to "Ongoing"
      await FirebaseFirestore.instance
          .collection('complaint')
          .doc(complaintId)
          .update({
            'reportStatus': 'Ongoing',
            'taskStartedAt': Timestamp.now(),
          });

      print('DEBUG startTask: Complaint status updated to Ongoing');

      // Start GPS tracking with continuous updates
      try {
        await gpsService.startTracking(
          updateInterval: const Duration(seconds: 10),
        );

        print('DEBUG startTask: GPS tracking started');

        // Subscribe to location updates and update Firestore
        gpsService.locationStream.listen((location) {
          print('DEBUG startTask: Location update received: ${location.latitude}, ${location.longitude}');
          _updateTechnicianLocationInFirestore(technicianDocId, location);
        });
      } catch (e) {
        print('Warning: Could not start GPS tracking: $e');
        // Task has been started even if tracking fails
      }
    } catch (e) {
      print('Error starting task: $e');
      rethrow;
    }
  }

  /// Mark technician as arrived at the location
  Future<void> markArrived(
    String complaintId,
    String technicianId,
  ) async {
    try {
      final now = Timestamp.now();

      // Update complaint with arrived timestamp
      await FirebaseFirestore.instance
          .collection('complaint')
          .doc(complaintId)
          .update({
            'reportStatus': 'ARRIVED',
            'arrivedAt': now,
          });

      // Update technician status
      await FirebaseFirestore.instance
          .collection('technician')
          .doc(technicianId)
          .update({
            'arrivedAt': now,
          });
    } catch (e) {
      print('Error marking arrived: $e');
      rethrow;
    }
  }

  /// Complete a task
  Future<void> completeTask(
    String complaintId,
    String technicianId,
  ) async {
    try {
      final now = Timestamp.now();

      // Update complaint status
      await FirebaseFirestore.instance
          .collection('complaint')
          .doc(complaintId)
          .update({
            'reportStatus': 'COMPLETED',
            'completedAt': now,
          });

      // Update technician status
      await FirebaseFirestore.instance
          .collection('technician')
          .doc(technicianId)
          .update({
            'currentTaskId': null,
            'isOnTask': false,
            'completedTaskAt': now,
          });

      // Stop GPS tracking
      final gpsService = GPSService();
      gpsService.stopTracking();
    } catch (e) {
      print('Error completing task: $e');
      rethrow;
    }
  }

  /// Update technician location in Firestore continuously
  Future<void> _updateTechnicianLocationInFirestore(
    String technicianId,
    LocationData location,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('technician')
          .doc(technicianId)
          .update({
            'currentLocation': GeoPoint(location.latitude, location.longitude),
            'locationUpdatedAt': Timestamp.now(),
          });
    } catch (e) {
      print('Error updating location in Firestore: $e');
    }
  }

  /// Get task status from Firestore
  Future<String> getTaskStatus(String complaintId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(complaintId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['reportStatus'] ?? 'PENDING';
      }
      return 'UNKNOWN';
    } catch (e) {
      print('Error getting task status: $e');
      return 'UNKNOWN';
    }
  }

  /// Watch task status in real-time
  Stream<String> watchTaskStatus(String complaintId) {
    return FirebaseFirestore.instance
        .collection('complaint')
        .doc(complaintId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['reportStatus'] ?? 'UNKNOWN';
    });
  }

  /// Get arrived timestamp
  Future<DateTime?> getArrivedTimestamp(String complaintId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(complaintId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final arrivedAt = data['arrivedAt'] as Timestamp?;
        if (arrivedAt != null) {
          return arrivedAt.toDate();
        }
      }
      return null;
    } catch (e) {
      print('Error getting arrived timestamp: $e');
      return null;
    }
  }

  /// Watch arrived timestamp in real-time
  Stream<DateTime?> watchArrivedTimestamp(String complaintId) {
    return FirebaseFirestore.instance
        .collection('complaint')
        .doc(complaintId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data() as Map<String, dynamic>?;
      final arrivedAt = data?['arrivedAt'] as Timestamp?;
      return arrivedAt?.toDate();
    });
  }
}
