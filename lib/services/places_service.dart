import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Model for Places API autocomplete prediction
class PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullDescription;

  PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullDescription,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      mainText: json['structured_formatting']?['main_text'] ?? '',
      secondaryText: json['structured_formatting']?['secondary_text'] ?? '',
      fullDescription: json['description'] ?? '',
    );
  }
}

/// Model for geocoding results
class GeocodeResult {
  final double latitude;
  final double longitude;
  final String formattedAddress;

  GeocodeResult({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);
}

/// Service for interacting with Google Places API
class PlacesService {
  final String _placesApiKey;
  final String _geocodingApiKey;
  final String _mapsApiKey;

  PlacesService({
    String? placesApiKey,
    String? geocodingApiKey,
    String? mapsApiKey,
  })  : _placesApiKey = placesApiKey ?? dotenv.env['PLACES_API_KEY'] ?? '',
        _geocodingApiKey = geocodingApiKey ?? dotenv.env['GEOCODING_API_KEY'] ?? '',
        _mapsApiKey = mapsApiKey ?? dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Get autocomplete suggestions for a search query
  /// 
  /// Returns a list of place predictions as user types
  Future<List<PlacePrediction>> getAutocompletePredictions(
    String input, {
    String sessionToken = '',
  }) async {
    if (input.isEmpty || _placesApiKey.isEmpty) return [];

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$input'
          '&key=$_placesApiKey'
          '${sessionToken.isNotEmpty ? '&sessiontoken=$sessionToken' : ''}';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final predictions = json['predictions'] as List?;
        
        if (predictions == null) return [];

        return predictions
            .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 403) {
        throw 'Places API access denied. Check your API key.';
      } else if (response.statusCode == 400) {
        throw 'Invalid request to Places API.';
      } else {
        throw 'Failed to fetch predictions: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Error fetching autocomplete: $e';
    }
  }

  /// Get place details including geometry (coordinates) from a place ID
  /// 
  /// Used to get the LatLng when user selects an address
  Future<GeocodeResult?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty || _placesApiKey.isEmpty) return null;

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=geometry,formatted_address'
          '&key=$_placesApiKey';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['result'] as Map<String, dynamic>?;

        if (result == null) return null;

        final geometry = result['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;

        if (location == null) return null;

        return GeocodeResult(
          latitude: location['lat'] ?? 0.0,
          longitude: location['lng'] ?? 0.0,
          formattedAddress: result['formatted_address'] ?? '',
        );
      } else {
        throw 'Failed to fetch place details: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Error fetching place details: $e';
    }
  }

  /// Geocode an address to get coordinates
  /// 
  /// Used to convert address strings to LatLng
  Future<GeocodeResult?> geocodeAddress(String address) async {
    if (address.isEmpty || _geocodingApiKey.isEmpty) return null;

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=${Uri.encodeComponent(address)}'
          '&key=$_geocodingApiKey';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final results = json['results'] as List?;

        if (results == null || results.isEmpty) return null;

        final firstResult = results[0] as Map<String, dynamic>;
        final geometry = firstResult['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;

        if (location == null) return null;

        return GeocodeResult(
          latitude: location['lat'] ?? 0.0,
          longitude: location['lng'] ?? 0.0,
          formattedAddress: firstResult['formatted_address'] ?? address,
        );
      } else {
        throw 'Geocoding failed: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Error geocoding address: $e';
    }
  }
}
