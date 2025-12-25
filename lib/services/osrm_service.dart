import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';

/// OSRM Service for route and ETA calculations
class OSRMService {
  static const String baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  /// Get route polyline and ETA between two points
  static Future<RouteData?> getRoute(
    LatLng startPoint,
    LatLng endPoint,
  ) async {
    try {
      final url =
          '$baseUrl/${startPoint.longitude},${startPoint.latitude};${endPoint.longitude},${endPoint.latitude}'
          '?overview=full&geometries=geojson';

      print('[OSRM DEBUG] Start: ${startPoint.latitude}, ${startPoint.longitude}');
      print('[OSRM DEBUG] End: ${endPoint.latitude}, ${endPoint.longitude}');
      print('[OSRM DEBUG] URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('OSRM request timed out');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['code'] != 'Ok' || json['routes'].isEmpty) {
          return null;
        }

        final route = json['routes'][0];
        final distance = (route['distance'] as num).toDouble();
        final duration = (route['duration'] as num).toDouble();
        
        print('[OSRM DEBUG] Distance: ${distance}m, Duration: ${duration}s (${duration / 3600}h)');
        print('[OSRM DEBUG] Response code: ${json['code']}, Routes: ${json['routes'].length}');

        // Extract coordinates from geometry
        final geometry = route['geometry'];
        final coordinates = (geometry['coordinates'] as List)
            .map((coord) => LatLng(
                  (coord[1] as num).toDouble(),
                  (coord[0] as num).toDouble(),
                ))
            .toList();

        return RouteData(
          polylinePoints: coordinates,
          distanceMeters: distance,
          durationSeconds: duration,
        );
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting route from OSRM: $e');
      return null;
    }
  }

  /// Get multiple routes for comparison
  static Future<List<RouteData>> getAlternativeRoutes(
    LatLng startPoint,
    LatLng endPoint,
  ) async {
    try {
      final url =
          '$baseUrl/${startPoint.longitude},${startPoint.latitude};${endPoint.longitude},${endPoint.latitude}'
          '?overview=full&geometries=geojson&alternatives=true';

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['code'] != 'Ok' || json['routes'].isEmpty) {
          return [];
        }

        final routes = (json['routes'] as List).map((route) {
          final distance = (route['distance'] as num).toDouble();
          final duration = (route['duration'] as num).toDouble();
          final geometry = route['geometry'];
          final coordinates = (geometry['coordinates'] as List)
              .map((coord) => LatLng(
                    (coord[1] as num).toDouble(),
                    (coord[0] as num).toDouble(),
                  ))
              .toList();

          return RouteData(
            polylinePoints: coordinates,
            distanceMeters: distance,
            durationSeconds: duration,
          );
        }).toList();

        return routes;
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting alternative routes: $e');
      return [];
    }
  }

  /// Reverse geocode coordinates to get address (using OSRM nearby)
  /// Note: OSRM doesn't provide reverse geocoding. For better results,
  /// consider using a free service like Nominatim or storing addresses manually.
  static Future<String?> reverseGeocode(LatLng location) async {
    try {
      // Using Nominatim OpenStreetMap service (free, no API key required)
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'KolejCare-App'},
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['address']['road'] ?? json['address']['city'] ?? 'Unknown Location';
      }
      return null;
    } catch (e) {
      print('Error reverse geocoding: $e');
      return null;
    }
  }

  /// Forward geocode address to get coordinates
  static Future<LatLng?> geocodeAddress(String address) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'KolejCare-App'},
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json.isNotEmpty) {
          final result = json[0];
          return LatLng(
            double.parse(result['lat']),
            double.parse(result['lon']),
          );
        }
      }
      return null;
    } catch (e) {
      print('Error geocoding address: $e');
      return null;
    }
  }

  /// Calculate distance between two points in meters (Haversine formula)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000; // Radius in meters
    final dLat = _toRad(point2.latitude - point1.latitude);
    final dLon = _toRad(point2.longitude - point1.longitude);

    final a = (1 - (cos(_toRad(point1.latitude)) * cos(_toRad(point2.latitude)))) / 2 +
        (cos(_toRad(point1.latitude)) * cos(_toRad(point2.latitude)) * (1 - cos(dLon))) / 2;

    return 2 * earthRadius * asin(sqrt(a.clamp(0.0, 1.0)));
  }

  static double _toRad(double degree) => degree * (pi / 180);

  static double _asin(double x) => 2 * atan2(x, sqrt(1 - x * x));

  static double _atan2(double y, double x) => atan2(y, x);
}
