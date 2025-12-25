import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Google Geocoding Service for address search and reverse geocoding
class GoogleGeocodingService {
  static String? _apiKey;
  
  static String get apiKey {
    _apiKey ??= dotenv.env['GEOCODING_API_KEY'] ?? dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (_apiKey!.isEmpty) {
      print('[GOOGLE GEOCODING] WARNING: GEOCODING_API_KEY or GOOGLE_MAPS_API_KEY not found in .env file');
    }
    return _apiKey!;
  }
  
  static const String geocodeBaseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
  static const String placesBaseUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';

  /// Geocode an address string to get coordinates
  static Future<LatLng?> geocodeAddress(String address) async {
    try {
      if (apiKey.isEmpty) {
        print('Error: Google Maps API key not found in .env');
        return null;
      }

      final url = Uri.parse(geocodeBaseUrl).replace(
        queryParameters: {
          'address': address,
          'key': apiKey,
        },
      );

      print('[GOOGLE GEOCODING] Geocoding address: $address');

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        if (json['results'].isNotEmpty) {
          final location = json['results'][0]['geometry']['location'];
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          
          print('[GOOGLE GEOCODING] Success: lat=$lat, lng=$lng');
          return LatLng(lat, lng);
        }
      }
      return null;
    } catch (e) {
      print('Error geocoding address: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to get address
  static Future<String?> reverseGeocode(LatLng location) async {
    try {
      if (apiKey.isEmpty) {
        print('Error: Google Maps API key not found in .env');
        return null;
      }

      final url = Uri.parse(geocodeBaseUrl).replace(
        queryParameters: {
          'latlng': '${location.latitude},${location.longitude}',
          'key': apiKey,
        },
      );

      print('[GOOGLE GEOCODING] Reverse geocoding: ${location.latitude},${location.longitude}');

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        if (json['results'].isNotEmpty) {
          final address = json['results'][0]['formatted_address'];
          print('[GOOGLE GEOCODING] Success: $address');
          return address;
        }
      }
      return null;
    } catch (e) {
      print('Error reverse geocoding: $e');
      return null;
    }
  }

  /// Get place autocomplete suggestions
  static Future<List<PlacePrediction>> getPlacePredictions(String input, {
    String? sessionToken,
    LatLng? bias,
  }) async {
    try {
      if (apiKey.isEmpty) {
        print('Error: Google Maps API key not found in .env');
        return [];
      }

      final queryParams = {
        'input': input,
        'key': apiKey,
        'language': 'en',
      };

      if (sessionToken != null) {
        queryParams['sessiontoken'] = sessionToken;
      }

      if (bias != null) {
        queryParams['location'] = '${bias.latitude},${bias.longitude}';
        queryParams['radius'] = '50000'; // 50km radius
      }

      final url = Uri.parse(placesBaseUrl).replace(queryParameters: queryParams);

      print('[GOOGLE PLACES] Searching: $input');

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        if (json['predictions'] != null) {
          final predictions = (json['predictions'] as List)
              .map((p) => PlacePrediction(
                    placeId: p['place_id'],
                    description: p['description'],
                    mainText: p['main_text'],
                    secondaryText: p['secondary_text'] ?? '',
                  ))
              .toList();
          
          print('[GOOGLE PLACES] Found ${predictions.length} suggestions');
          return predictions;
        }
      }
      return [];
    } catch (e) {
      print('Error getting place predictions: $e');
      return [];
    }
  }

  /// Get place details using place ID
  static Future<PlaceDetails?> getPlaceDetails(String placeId, {
    String? sessionToken,
  }) async {
    try {
      if (apiKey.isEmpty) {
        print('Error: Google Maps API key not found in .env');
        return null;
      }

      final queryParams = {
        'place_id': placeId,
        'fields': 'geometry,formatted_address,name',
        'key': apiKey,
      };

      if (sessionToken != null) {
        queryParams['sessiontoken'] = sessionToken;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json',
      ).replace(queryParameters: queryParams);

      print('[GOOGLE PLACES] Getting details for place: $placeId');

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        if (json['result'] != null) {
          final result = json['result'];
          final location = result['geometry']['location'];
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();

          return PlaceDetails(
            address: result['formatted_address'],
            name: result['name'],
            latitude: lat,
            longitude: lng,
          );
        }
      }
      return null;
    } catch (e) {
      print('Error getting place details: $e');
      return null;
    }
  }
}

/// Model for place prediction
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  @override
  String toString() => description;
}

/// Model for place details
class PlaceDetails {
  final String address;
  final String name;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.address,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}
