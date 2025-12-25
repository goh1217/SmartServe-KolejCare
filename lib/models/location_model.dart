import 'package:latlong2/latlong.dart';

/// Model for location coordinates
class LocationData {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.address,
    required this.timestamp,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      address: map['address'],
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
    );
  }
}

/// Model for OSRM route response
class RouteData {
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final double durationSeconds;

  RouteData({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  Duration get estimatedDuration => Duration(seconds: durationSeconds.toInt());

  /// Get adjusted duration with buffer for real-world conditions
  /// OSRM provides theoretical time; add 35% buffer for realistic ETA
  Duration get adjustedDuration => Duration(
    seconds: (durationSeconds * 1.35).toInt(),
  );

  String get estimatedArrivalTime {
    final duration = adjustedDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '$hours h $minutes min';
    }
    return '$minutes min';
  }

  /// Get actual arrival time (current time + duration)
  String get actualArrivalTime {
    final now = DateTime.now();
    final arrivalTime = now.add(adjustedDuration);
    return '${arrivalTime.hour}:${arrivalTime.minute.toString().padLeft(2, '0')}';
  }

  String get estimatedArrivalTimeDetailed {
    final duration = adjustedDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final distKm = (distanceMeters / 1000).toStringAsFixed(1);
    
    if (hours > 0) {
      return '$hours h $minutes min ($distKm km)';
    }
    return '$minutes min ($distKm km)';
  }

  double get distanceKm => distanceMeters / 1000;
}

/// Model for Technician location tracking
class TechnicianLocation {
  final String technicianId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final bool isActive;

  TechnicianLocation({
    required this.technicianId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.isActive = true,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory TechnicianLocation.fromMap(
      Map<String, dynamic> map, String technicianId) {
    return TechnicianLocation(
      technicianId: technicianId,
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }
}
