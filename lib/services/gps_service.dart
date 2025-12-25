import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';

/// Service for managing GPS location tracking
class GPSService {
  static final GPSService _instance = GPSService._internal();

  factory GPSService() {
    return _instance;
  }

  GPSService._internal();

  final StreamController<LocationData> _locationController =
      StreamController<LocationData>.broadcast();
  Timer? _updateTimer;
  bool _isTracking = false;
  LocationData? _lastLocation;

  Stream<LocationData> get locationStream => _locationController.stream;

  /// Check and request location permissions
  static Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.whileInUse ||
          result == LocationPermission.always;
    }

    if (permission == LocationPermission.deniedForever) {
      // User has denied permissions permanently
      await Geolocator.openLocationSettings();
      return false;
    }

    return true;
  }

  /// Start continuous location tracking
  Future<void> startTracking({
    Duration updateInterval = const Duration(seconds: 10),
  }) async {
    if (_isTracking) return;

    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    _isTracking = true;

    // Initial location fetch
    try {
      await _fetchAndEmitLocation();
    } catch (e) {
      print('Error fetching initial location: $e');
    }

    // Periodic updates
    _updateTimer = Timer.periodic(updateInterval, (_) async {
      if (_isTracking) {
        try {
          await _fetchAndEmitLocation();
        } catch (e) {
          print('Error updating location: $e');
        }
      }
    });
  }

  /// Stop location tracking
  void stopTracking() {
    _isTracking = false;
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Get current location once
  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Fetch current location and emit to stream
  Future<void> _fetchAndEmitLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      _lastLocation = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );

      if (!_locationController.isClosed) {
        _locationController.add(_lastLocation!);
      }
    } catch (e) {
      print('Error in _fetchAndEmitLocation: $e');
    }
  }

  /// Update technician location in Firestore
  static Future<void> updateTechnicianLocation(
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
      print('Error updating technician location: $e');
    }
  }

  /// Get technician's current location from Firestore
  static Future<LocationData?> getTechnicianLocation(
    String technicianId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('technician')
          .doc(technicianId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final currentLocation = data['currentLocation'];

        if (currentLocation != null && currentLocation is GeoPoint) {
          return LocationData(
            latitude: currentLocation.latitude,
            longitude: currentLocation.longitude,
            timestamp: data['locationUpdatedAt'] != null
                ? (data['locationUpdatedAt'] as Timestamp).toDate()
                : DateTime.now(),
          );
        }
      }
      return null;
    } catch (e) {
      print('Error getting technician location: $e');
      return null;
    }
  }

  /// Watch technician location in real-time from Firestore
  static Stream<LocationData> watchTechnicianLocation(String technicianId) {
    return FirebaseFirestore.instance
        .collection('technician')
        .doc(technicianId)
        .snapshots()
        .map((snapshot) {
      try {
        final data = snapshot.data();
        if (data != null) {
          final currentLocation = data['currentLocation'];
          if (currentLocation != null && currentLocation is GeoPoint) {
            return LocationData(
              latitude: currentLocation.latitude,
              longitude: currentLocation.longitude,
              timestamp: DateTime.now(),
            );
          }
        }
        throw Exception('No location data available');
      } catch (e) {
        throw Exception('Error parsing location: $e');
      }
    });
  }

  /// Cleanup resources
  void dispose() {
    stopTracking();
    _locationController.close();
  }
}
