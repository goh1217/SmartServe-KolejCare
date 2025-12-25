import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();

  factory LocationTrackingService() {
    return _instance;
  }

  LocationTrackingService._internal();

  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, dynamic> _cachedLocations = {};

  /// Start tracking a technician's location in real-time
  /// Fetches the technician's currentLocation every 10 seconds
  Stream<LatLng?> trackTechnicianLocation(String technicianId) {
    final controller = StreamController<LatLng?>();

    // Cancel existing subscription if any
    _subscriptions[technicianId]?.cancel();

    // Set up periodic polling every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('technician')
            .doc(technicianId)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final currentLocation = data['currentLocation'];

          if (currentLocation is GeoPoint) {
            final latLng = LatLng(currentLocation.latitude, currentLocation.longitude);
            _cachedLocations[technicianId] = latLng;
            controller.add(latLng);
          } else {
            // Try to get from cache if current location is not available
            final cached = _cachedLocations[technicianId];
            if (cached != null) {
              controller.add(cached as LatLng);
            } else {
              controller.add(null);
            }
          }
        } else {
          controller.add(null);
        }
      } catch (e) {
        print('Error tracking technician location: $e');
        controller.add(null);
      }
    });

    // Store the subscription for cleanup
    _subscriptions[technicianId] = controller.stream.listen(
      (_) {},
      onError: (e) => print('Location stream error: $e'),
      onDone: () {
        _subscriptions.remove(technicianId);
      },
    );

    return controller.stream;
  }

  /// Get the last known location for a technician (from cache)
  LatLng? getLastKnownLocation(String technicianId) {
    return _cachedLocations[technicianId] as LatLng?;
  }

  /// Stop tracking a technician's location
  void stopTracking(String technicianId) {
    _subscriptions[technicianId]?.cancel();
    _subscriptions.remove(technicianId);
  }

  /// Stop tracking all technicians
  void stopAllTracking() {
    _subscriptions.forEach((_, subscription) {
      subscription.cancel();
    });
    _subscriptions.clear();
  }

  /// Get the current location of a technician (one-time fetch)
  Future<LatLng?> getTechnicianCurrentLocation(String technicianId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('technician')
          .doc(technicianId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final currentLocation = data['currentLocation'];

        if (currentLocation is GeoPoint) {
          return LatLng(currentLocation.latitude, currentLocation.longitude);
        }
      }
      return null;
    } catch (e) {
      print('Error getting technician location: $e');
      return null;
    }
  }
}
