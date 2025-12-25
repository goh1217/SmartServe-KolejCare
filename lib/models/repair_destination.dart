import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Model to represent the repair destination location
/// Used by technicians to navigate to the repair location
class RepairDestination {
  /// Firestore GeoPoint for the repair location
  final GeoPoint geoPoint;

  /// Human-readable address for the repair location
  final String address;

  /// Latitude extracted from geoPoint for convenience
  double get latitude => geoPoint.latitude;

  /// Longitude extracted from geoPoint for convenience
  double get longitude => geoPoint.longitude;

  /// LatLng object for use with flutter_map
  LatLng get latLng => LatLng(latitude, longitude);

  /// Type of location (e.g., "Room", "Common Area", "Laboratory")
  final String? locationType;

  /// Additional notes about the repair destination
  final String? notes;

  /// Timestamp when this destination was created
  final DateTime? createdAt;

  RepairDestination({
    required this.geoPoint,
    required this.address,
    this.locationType,
    this.notes,
    this.createdAt,
  });

  /// Create a RepairDestination from Firestore document
  factory RepairDestination.fromFirestore(Map<String, dynamic> data) {
    return RepairDestination(
      geoPoint: data['geoPoint'] as GeoPoint,
      address: data['address'] as String? ?? 'Unknown Location',
      locationType: data['locationType'] as String?,
      notes: data['notes'] as String?,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert RepairDestination to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'geoPoint': geoPoint,
      'address': address,
      if (locationType != null) 'locationType': locationType,
      if (notes != null) 'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  /// Create a RepairDestination from coordinates and address
  factory RepairDestination.fromCoordinates({
    required double latitude,
    required double longitude,
    required String address,
    String? locationType,
    String? notes,
  }) {
    return RepairDestination(
      geoPoint: GeoPoint(latitude, longitude),
      address: address,
      locationType: locationType,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  /// Create a copy of RepairDestination with modified fields
  RepairDestination copyWith({
    GeoPoint? geoPoint,
    String? address,
    String? locationType,
    String? notes,
    DateTime? createdAt,
  }) {
    return RepairDestination(
      geoPoint: geoPoint ?? this.geoPoint,
      address: address ?? this.address,
      locationType: locationType ?? this.locationType,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get Google Maps URL for this destination
  String get googleMapsUrl {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  /// Get Google Maps direction URL from current location
  String googleMapsDirectionUrl({
    required double originLatitude,
    required double originLongitude,
  }) {
    return 'https://www.google.com/maps/dir/$originLatitude,$originLongitude/$latitude,$longitude';
  }

  @override
  String toString() {
    return 'RepairDestination(address: $address, lat: $latitude, lng: $longitude, type: $locationType)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepairDestination &&
          runtimeType == other.runtimeType &&
          geoPoint == other.geoPoint &&
          address == other.address;

  @override
  int get hashCode => geoPoint.hashCode ^ address.hashCode;
}
