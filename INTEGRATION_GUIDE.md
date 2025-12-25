# Integration Example: Complete Feature Usage

This document shows how the Google Places API integration is used in the complaint form.

---

## How the Feature Works: Complete Flow

### File Structure
```
lib/
├── student/
│   └── complaint_form_screen.dart      # Main form with location integration
├── services/
│   └── places_service.dart             # Google Places API interactions
└── widgets/
    └── location_picker_widget.dart     # Location selection UI widget
```

---

## 1. User Selects Location Mode

### Code in complaint_form_screen.dart
```dart
// State variable to track selected mode
String? _locationChoice; // "room" or "public"

// Dropdown widget
DropdownButtonFormField<String>(
  value: _locationChoice,
  items: const [
    DropdownMenuItem(value: "room", child: Text("Inside My Room")),
    DropdownMenuItem(value: "public", child: Text("Public Area")),
  ],
  onChanged: (v) {
    setState(() {
      _locationChoice = v;
      // Clear previous selections
      _locationAddressController.clear();
      _selectedAddress = null;
      _selectedLatitude = null;
      _selectedLongitude = null;
    });
  },
)
```

---

## 2a. Room Mode: Auto-Populate Address

### Fetch Student Data (On App Start)
```dart
@override
void initState() {
  super.initState();
  _fetchStudentData();  // Automatically called
}

Future<void> _fetchStudentData() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'User not logged in';

    // Fetch from Firestore
    final studentDoc = await FirebaseFirestore.instance
        .collection('student')
        .doc(user.uid)
        .get();

    if (!studentDoc.exists) throw 'Student record not found';

    if (mounted) {
      setState(() {
        _studentData = studentDoc.data();  // Contains: residentCollege, block, roomNumber
        _isLoadingStudentData = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _studentDataError = e.toString();
        _isLoadingStudentData = false;
      });
    }
  }
}
```

### Expected Firestore Document Structure
```
Collection: student
Document: {user_uid}
{
  "residentCollege": "St. Catherine's College",
  "block": "A",
  "roomNumber": "201",
  "email": "student@example.com",
  ... other fields
}
```

### Format Address for Room Mode
```dart
String _getInitialRoomAddress() {
  if (_studentData == null) return '';
  
  final college = _studentData?['residentCollege'] ?? '';
  final block = _studentData?['block'] ?? '';
  final room = _studentData?['roomNumber'] ?? '';
  
  final parts = [college, block, room].where((p) => p.isNotEmpty).toList();
  return parts.join(', ');
  
  // Result: "St. Catherine's College, A, 201"
}
```

### Display LocationPickerWidget for Room Mode
```dart
if (_locationChoice == "room") {
  LocationPickerWidget(
    locationMode: "room",
    addressController: _locationAddressController,
    initialAddress: _getInitialRoomAddress(),  // Auto-populates
    editableAddress: true,                      // User can edit
    descriptionController: _locationDescriptionController,
    onLocationSelected: (result) {
      setState(() {
        _selectedAddress = result.address;
        _selectedLatitude = result.latitude;
        _selectedLongitude = result.longitude;
      });
    },
  )
}
```

### User Edits Address (Room Mode)
```dart
// User clears field and types new address
// Taps "Update Location" button in LocationPickerWidget
// LocationPickerWidget calls PlacesService.geocodeAddress()

Future<void> _geocodeAddress(String address) async {
  try {
    final result = await _placesService.geocodeAddress(address);
    // Returns GeocodeResult with latitude, longitude, formattedAddress
    
    if (result != null) {
      // Update map with new location
      _updateMapWithLocation(result);
      
      // Notify parent widget
      widget.onLocationSelected(
        LocationPickerResult(
          address: result.formattedAddress,
          latitude: result.latitude,
          longitude: result.longitude,
        ),
      );
    }
  } catch (e) {
    // Show error message
  }
}
```

---

## 2b. Public Area Mode: Search and Select

### User Types Address
```dart
// LocationPickerWidget listens to TextEditingController
void _onAddressChanged() {
  _debounce?.cancel();
  
  if (widget.addressController.text.isEmpty) {
    setState(() {
      _predictions = [];
      _showPredictions = false;
    });
    return;
  }

  // Wait 500ms after user stops typing
  _debounce = Timer(const Duration(milliseconds: 500), () {
    _fetchPredictions(widget.addressController.text);
  });
}

Future<void> _fetchPredictions(String input) async {
  // Call Places API
  final predictions = await _placesService.getAutocompletePredictions(
    input,
    sessionToken: _sessionToken,
  );
  
  // Show suggestions in dropdown
  setState(() {
    _predictions = predictions;  // List of PlacePrediction objects
    _showPredictions = predictions.isNotEmpty;
  });
}
```

### Display Autocomplete Suggestions
```dart
// In LocationPickerWidget build method
if (_showPredictions && _predictions.isNotEmpty)
  Container(
    child: Column(
      children: _predictions
          .take(5)  // Show only 5 suggestions
          .map((prediction) => _buildPredictionTile(prediction))
          .toList(),
    ),
  ),

Widget _buildPredictionTile(PlacePrediction prediction) {
  return InkWell(
    onTap: () => _selectPrediction(prediction),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prediction.mainText),      // e.g., "Main Library"
                if (prediction.secondaryText.isNotEmpty)
                  Text(prediction.secondaryText),  // e.g., "University Road, Cambridge"
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

### User Selects Suggestion
```dart
Future<void> _selectPrediction(PlacePrediction prediction) async {
  // Update text field
  widget.addressController.text = prediction.fullDescription;
  
  // Get place details (coordinates)
  try {
    final placeDetails = await _placesService.getPlaceDetails(
      prediction.placeId
    );
    
    if (placeDetails != null) {
      // Update map
      _updateMapWithLocation(placeDetails);
      
      // Notify parent
      widget.onLocationSelected(
        LocationPickerResult(
          address: placeDetails.formattedAddress,
          latitude: placeDetails.latitude,
          longitude: placeDetails.longitude,
        ),
      );
    }
  } catch (e) {
    // Show error
  }
}
```

---

## 3. Google Map Display

### Map Appears After Address Selected
```dart
if (_selectedLocation != null)
  Container(
    height: 280,
    child: GoogleMap(
      onMapCreated: (controller) {
        _mapController = controller;
      },
      initialCameraPosition: CameraPosition(
        target: _selectedLocation!,  // Center on location
        zoom: 17.0,                  // Street level zoom
      ),
      markers: _markers,             // Show marker at location
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
    ),
  ),
```

### Update Map with New Location
```dart
void _updateMapWithLocation(GeocodeResult result) {
  final newLocation = LatLng(result.latitude, result.longitude);

  setState(() {
    _selectedLocation = newLocation;
    _markers = {
      Marker(
        markerId: const MarkerId('selected_location'),
        position: newLocation,
        infoWindow: InfoWindow(
          title: 'Selected Location',
          snippet: result.formattedAddress,
        ),
      ),
    };
  });

  // Animate map to new location
  _mapController?.animateCamera(
    CameraUpdate.newCameraPosition(
      CameraPosition(
        target: newLocation,
        zoom: 17.0,
      ),
    ),
  );
}
```

---

## 4. Description Field

### Optional Notes About Location
```dart
if (widget.descriptionController != null)
  Container(
    child: TextField(
      controller: widget.descriptionController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Add additional details about the location...',
      ),
    ),
  ),
```

---

## 5. Form Submission

### Collect Location Data
```dart
Future<void> _handleSubmit() async {
  // Validation
  if (_selectedAddress == null || _selectedAddress!.isEmpty) {
    _showErrorDialog('Incomplete', 'Please select a location.');
    return;
  }

  try {
    // Create complaint document with location
    final docRef = await FirebaseFirestore.instance
        .collection('complaint')
        .add({
          'damageLocation': _selectedAddress,              // e.g., "Main Library"
          'damageLocationLatitude': _selectedLatitude,     // 50.7345
          'damageLocationLongitude': _selectedLongitude,   // -3.5321
          'damageLocationDescription': _locationDescriptionController.text,
          'damageLocationType': _locationChoice,           // 'room' or 'public'
          'reportedDate': FieldValue.serverTimestamp(),
          // ... other fields
        });

    // Upload images
    // ...

    _showSuccessDialog('Success!', 'Complaint submitted successfully.');
  } catch (e) {
    _showErrorDialog('Error', 'Failed to submit complaint: $e');
  }
}
```

---

## 6. Services Layer: Google Places API

### PlacesService Class
```dart
class PlacesService {
  final String _apiKey;

  PlacesService({String? apiKey})
      : _apiKey = apiKey ?? dotenv.env['PLACES_API_KEY'] ?? '';

  /// Get autocomplete suggestions
  Future<List<PlacePrediction>> getAutocompletePredictions(
    String input, {
    String sessionToken = '',
  }) async {
    // Call Google Places API
    final String url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$input'
        '&key=$_apiKey'
        '${sessionToken.isNotEmpty ? '&sessiontoken=$sessionToken' : ''}';

    final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final predictions = json['predictions'] as List?;
      
      return predictions
          ?.map((p) => PlacePrediction.fromJson(p))
          .toList() ?? [];
    }
    throw 'Failed to fetch predictions';
  }

  /// Get coordinates for a place
  Future<GeocodeResult?> getPlaceDetails(String placeId) async {
    final String url = 'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry,formatted_address'
        '&key=$_apiKey';

    final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final result = json['result'] as Map<String, dynamic>?;
      final geometry = result?['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;

      if (location != null) {
        return GeocodeResult(
          latitude: location['lat'] ?? 0.0,
          longitude: location['lng'] ?? 0.0,
          formattedAddress: result?['formatted_address'] ?? '',
        );
      }
    }
    throw 'Failed to fetch place details';
  }

  /// Geocode address string to coordinates
  Future<GeocodeResult?> geocodeAddress(String address) async {
    final String url = 'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&key=$_apiKey';

    final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final results = json['results'] as List?;
      
      if (results?.isNotEmpty ?? false) {
        final firstResult = results![0] as Map<String, dynamic>;
        final geometry = firstResult['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;

        if (location != null) {
          return GeocodeResult(
            latitude: location['lat'] ?? 0.0,
            longitude: location['lng'] ?? 0.0,
            formattedAddress: firstResult['formatted_address'] ?? address,
          );
        }
      }
    }
    throw 'Geocoding failed';
  }
}
```

---

## 7. Data Models

### PlacePrediction
```dart
class PlacePrediction {
  final String placeId;           // Unique place ID
  final String mainText;          // e.g., "Main Library"
  final String secondaryText;     // e.g., "University Road"
  final String fullDescription;   // Complete address

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
```

### GeocodeResult
```dart
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
```

### LocationPickerResult
```dart
class LocationPickerResult {
  final String address;
  final double latitude;
  final double longitude;

  LocationPickerResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}
```

---

## 8. Error Handling Examples

### Invalid Address
```dart
// User searches for "xyzabc123"
// API returns empty predictions list
// UI shows: (no dropdown appears)
// Can show error after delay: "Address not found"
```

### Network Error
```dart
try {
  final predictions = await _placesService.getAutocompletePredictions(input);
} catch (e) {
  // e.toString() = "Error fetching autocomplete: ..."
  setState(() {
    _errorMessage = 'Error: ${e.toString()}';
  });
  // UI shows error in red box
}
```

### Missing Student Data
```dart
// Room mode selected but student document not found in Firestore
_studentDataError = 'Student record not found'
// UI shows error message instead of location picker
```

### Invalid API Key
```dart
// PLACES_API_KEY in .env is wrong
// API response: 403 Forbidden
// Error message: "Places API access denied. Check your API key."
```

---

## 9. Testing the Integration

### Test Case 1: Public Area
```
1. Open complaint form
2. Select "Public Area"
3. Type "library" in address field
4. Wait ~700ms
5. Autocomplete suggestions appear
6. Tap first suggestion
7. Map appears with marker
8. Verify marker is at correct location
9. Fill other form fields
10. Submit
11. Check Firestore: damageLocation, coordinates, damageLocationType="public"
```

### Test Case 2: Room Mode
```
1. Open complaint form
2. Select "Inside My Room"
3. Wait for student data to load
4. Address field auto-populated with room location
5. Map appears automatically
6. Clear address and type new location
7. Tap "Update Location"
8. Map updates to new location
9. Fill other form fields
10. Submit
11. Check Firestore: damageLocationType="room"
```

### Test Case 3: Error Handling
```
1. Enable airplane mode
2. Try to search address
3. Get error message: "Error fetching autocomplete"
4. Disable airplane mode
5. Try again
6. Should work normally
```

---

## 10. Performance Notes

### Session Tokens
- Reduce API costs by ~25%
- Generated once when widget is created: `DateTime.now().millisecondsSinceEpoch.toString()`
- Used for all autocomplete calls in session

### Debouncing
- 500ms wait after user stops typing
- Prevents excessive API calls
- Improves UX (no flickering)

### Rate Limiting
- 5-second timeout on all API requests
- Prevents hanging requests
- Shows error if exceeded

---

## Summary

The integration provides:
1. ✅ Automatic address lookup with Google Places API
2. ✅ Interactive Google Map display
3. ✅ Support for two location modes (room/public)
4. ✅ Proper error handling
5. ✅ Location data stored in Firestore with coordinates
6. ✅ Null-safe throughout
7. ✅ Responsive UI with loading indicators

---

Last Updated: December 25, 2025
