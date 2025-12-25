import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/location_model.dart';

/// Google Maps Directions Service for route and ETA calculations
/// Replaces OSRM with Google Maps API for better consistency and accuracy
class GoogleDirectionsService {
  static final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static const String directionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Get route polyline and ETA between two points using Google Maps Directions API
  static Future<RouteData?> getRoute(
    LatLng startPoint,
    LatLng endPoint,
  ) async {
    try {
      if (apiKey.isEmpty) {
        print('[GOOGLE DIRECTIONS] Error: Google Maps API key not found in .env');
        return null;
      }

      final url = Uri.parse(directionsBaseUrl).replace(
        queryParameters: {
          'origin': '${startPoint.latitude},${startPoint.longitude}',
          'destination': '${endPoint.latitude},${endPoint.longitude}',
          'key': apiKey,
          'mode': 'driving',
          'alternatives': 'false',
        },
      );

      print('[GOOGLE DIRECTIONS] Start: ${startPoint.latitude}, ${startPoint.longitude}');
      print('[GOOGLE DIRECTIONS] End: ${endPoint.latitude}, ${endPoint.longitude}');
      print('[GOOGLE DIRECTIONS] URL: $url');

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Google Directions request timed out');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['status'] != 'OK' || (json['routes'] as List).isEmpty) {
          print('[GOOGLE DIRECTIONS] Status: ${json['status']}, Routes: ${(json['routes'] as List).length}');
          return null;
        }

        final route = json['routes'][0];
        final leg = route['legs'][0];

        // Get distance in meters and duration in seconds
        final distance = (leg['distance']['value'] as num).toDouble(); // in meters
        final duration = (leg['duration']['value'] as num).toDouble(); // in seconds

        print('[GOOGLE DIRECTIONS] Distance: ${distance}m, Duration: ${duration}s (${duration / 3600} hours)');
        print('[GOOGLE DIRECTIONS] Status: ${json['status']}, Routes: ${(json['routes'] as List).length}');

        // Extract coordinates from all steps' polylines
        final coordinates = <LatLng>[];
        final steps = leg['steps'] as List;

        for (final step in steps) {
          final polyline = step['polyline']['points'] as String;
          final decodedPoints = _decodePolyline(polyline);
          coordinates.addAll(decodedPoints);
        }

        // Ensure we have points
        if (coordinates.isEmpty) {
          print('[GOOGLE DIRECTIONS] Warning: No coordinates extracted from polyline');
          // Fallback: just create a line between start and end
          coordinates.addAll([startPoint, endPoint]);
        }

        return RouteData(
          polylinePoints: coordinates,
          distanceMeters: distance,
          durationSeconds: duration,
        );
      } else {
        print('[GOOGLE DIRECTIONS] Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[GOOGLE DIRECTIONS] Error getting route: $e');
      return null;
    }
  }

  /// Decode polyline points from Google Maps Directions API response
  /// Google Maps encodes polylines using the Encoded Polyline Algorithm
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(
        (lat / 1E5).toDouble(),
        (lng / 1E5).toDouble(),
      ));
    }

    return poly;
  }

  /// Get multiple routes for comparison
  static Future<List<RouteData>> getAlternativeRoutes(
    LatLng startPoint,
    LatLng endPoint,
  ) async {
    try {
      if (apiKey.isEmpty) {
        print('[GOOGLE DIRECTIONS] Error: Google Maps API key not found in .env');
        return [];
      }

      final url = Uri.parse(directionsBaseUrl).replace(
        queryParameters: {
          'origin': '${startPoint.latitude},${startPoint.longitude}',
          'destination': '${endPoint.latitude},${endPoint.longitude}',
          'key': apiKey,
          'mode': 'driving',
          'alternatives': 'true',
        },
      );

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['status'] != 'OK' || (json['routes'] as List).isEmpty) {
          return [];
        }

        final routes = <RouteData>[];
        for (final route in (json['routes'] as List)) {
          final leg = route['legs'][0];
          final distance = (leg['distance']['value'] as num).toDouble();
          final duration = (leg['duration']['value'] as num).toDouble();

          // Extract coordinates from all steps
          final coordinates = <LatLng>[];
          for (final step in (leg['steps'] as List)) {
            final polyline = step['polyline']['points'] as String;
            final decodedPoints = _decodePolyline(polyline);
            coordinates.addAll(decodedPoints);
          }

          if (coordinates.isEmpty) {
            coordinates.addAll([startPoint, endPoint]);
          }

          routes.add(RouteData(
            polylinePoints: coordinates,
            distanceMeters: distance,
            durationSeconds: duration,
          ));
        }

        return routes;
      } else {
        return [];
      }
    } catch (e) {
      print('[GOOGLE DIRECTIONS] Error getting alternative routes: $e');
      return [];
    }
  }
}
