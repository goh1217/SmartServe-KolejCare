import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ETAService {
  static final ETAService _instance = ETAService._internal();

  factory ETAService() {
    return _instance;
  }

  ETAService._internal();

  /// Calculate ETA using Google Directions API
  /// Returns duration in minutes
  Future<int> calculateETAMinutes({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    try {
      final directionApiKey = dotenv.env['DIRECTION_API_KEY'] ?? '';
      if (directionApiKey.isEmpty) {
        print('WARNING: DIRECTION_API_KEY not found in .env');
        return 30; // Default fallback
      }

      final url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$originLat,$originLng'
          '&destination=$destinationLat,$destinationLng'
          '&key=$directionApiKey'
          '&mode=driving'
          '&alternatives=false';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['status'] == 'OK' && json['routes'] != null && json['routes'].isNotEmpty) {
          final route = json['routes'][0];
          if (route['legs'] != null && route['legs'].isNotEmpty) {
            final leg = route['legs'][0];
            if (leg['duration'] != null) {
              final durationSeconds = leg['duration']['value'] as int?;
              if (durationSeconds != null) {
                final eta = (durationSeconds / 60).ceil();
                print('DEBUG: ETA calculated via Directions API: $eta minutes');
                return eta;
              }
            }
          }
        }

        print('DEBUG: Unexpected Directions API response: ${json['status']}');
        return 30; // Default fallback
      } else {
        print('ERROR: Directions API returned status ${response.statusCode}');
        print('Response: ${response.body}');
        return 30; // Default fallback
      }
    } catch (e) {
      print('Error calculating ETA with Directions API: $e');
      return 30; // Default fallback on error
    }
  }

  /// Calculate ETA and return formatted string
  Future<String> getETAText({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final eta = await calculateETAMinutes(
      originLat: originLat,
      originLng: originLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
    );
    return 'ETA: $eta mins';
  }
}
