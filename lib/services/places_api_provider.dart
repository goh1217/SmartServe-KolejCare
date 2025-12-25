import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Address suggestion model
@immutable
class AddressSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  const AddressSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });
}

/// Google Places API service for address autocomplete
class PlacesApiProvider {
  final Client client = Client();
  final String? sessionToken;
  
  static String? _apiKey;
  
  static String get apiKey {
    _apiKey ??= dotenv.env['PLACES_API_KEY'] ?? dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (_apiKey!.isEmpty) {
      print('[PLACES API] WARNING: PLACES_API_KEY or GOOGLE_MAPS_API_KEY not found in .env file');
    } else {
      print('[PLACES API] API Key loaded: ${_apiKey!.substring(0, 10)}...');
    }
    return _apiKey!;
  }

  PlacesApiProvider(this.sessionToken);

  /// Fetch address suggestions based on input
  Future<List<AddressSuggestion>> fetchSuggestions(
    String input,
    String languageCode, {
    LatLng? bias,
  }) async {
    if (input.isEmpty) {
      print('[PLACES API] Empty input, returning empty list');
      return <AddressSuggestion>[];
    }

    // Check if API key is available
    final key = apiKey;
    if (key.isEmpty) {
      print('[PLACES API] ERROR: API key not configured');
      return [];
    }

    print('[PLACES API] API key is configured: ${key.substring(0, 10)}...');

    final Uri requestUri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
    );

    final Map<String, String> queryParams = {
      'input': input,
      'key': key,
      'language': languageCode,
      'sessiontoken': sessionToken ?? '',
    };

    // Add location bias if provided
    if (bias != null) {
      queryParams['location'] = '${bias.latitude},${bias.longitude}';
      queryParams['radius'] = '50000'; // 50km radius for bias
      print('[PLACES API] Added location bias: ${bias.latitude}, ${bias.longitude}');
    }

    try {
      print('[PLACES API] Making request to: ${requestUri.replace(queryParameters: queryParams).toString().substring(0, 100)}...');
      print('[PLACES API] Params - input: "$input", lang: "$languageCode", sessionToken: "$sessionToken"');
      
      final response = await client.get(requestUri.replace(queryParameters: queryParams)).timeout(
        const Duration(seconds: 10),
      );

      print('[PLACES API] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('[PLACES API] Response body length: ${response.body.length}');
        return _parseSuggestions(response.body);
      } else {
        print('[PLACES API] Error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e, stackTrace) {
      print('[PLACES API] Request exception: $e');
      print('[PLACES API] Stack: $stackTrace');
      return [];
    }
  }

  /// Parse suggestions from API response
  List<AddressSuggestion> _parseSuggestions(String responseBody) {
    try {
      final result = jsonDecode(responseBody);
      if (result['predictions'] == null || result['predictions'].isEmpty) {
        return [];
      }

      return (result['predictions'] as List)
          .map<AddressSuggestion>((json) => AddressSuggestion(
                placeId: json['place_id'] as String? ?? '',
                mainText:
                    json['structured_formatting']['main_text'] as String? ??
                        '',
                secondaryText:
                    json['structured_formatting']['secondary_text'] as String? ??
                        '',
                fullText: json['description'] as String? ?? '',
              ))
          .toList();
    } catch (e) {
      print('[PLACES API] Parse error: $e');
      return [];
    }
  }

  /// Get coordinates from place ID
  Future<LatLng?> getPlaceCoordinatesFromId(String placeId) async {
    final Uri requestUri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': apiKey,
        'fields': 'geometry,formatted_address',
        'sessiontoken': sessionToken ?? '',
      },
    );

    try {
      print('[PLACES API] Fetching coordinates for placeId: $placeId');
      final response = await client.get(requestUri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        return _parseCoordinates(response.body);
      } else {
        print('[PLACES API] Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[PLACES API] Request failed: $e');
      return null;
    }
  }

  /// Parse coordinates from API response
  LatLng? _parseCoordinates(String responseBody) {
    try {
      final result = jsonDecode(responseBody);
      if (result['result'] == null || result['result']['geometry'] == null) {
        return null;
      }

      final location = result['result']['geometry']['location'];
      if (location != null && location['lat'] != null && location['lng'] != null) {
        return LatLng(
          location['lat'] as double,
          location['lng'] as double,
        );
      }
      return null;
    } catch (e) {
      print('[PLACES API] Parse error: $e');
      return null;
    }
  }
}
