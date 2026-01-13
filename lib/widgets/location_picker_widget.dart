import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/places_service.dart';
import 'dart:async';

/// Widget for handling location/address selection with Maps
/// 
/// Supports two modes:
/// 1. Public Area: Free-form address search with autocomplete
/// 2. Inside My Room: Auto-populated address with ability to edit
class LocationPickerWidget extends StatefulWidget {
  /// 'room' or 'public'
  final String? locationMode;
  
  /// Controller for the address input field
  final TextEditingController addressController;
  
  /// Callback when location is successfully selected
  final Function(LocationPickerResult) onLocationSelected;
  
  /// Pre-populated address (for room mode)
  final String? initialAddress;
  
  /// Enable editing of address
  final bool editableAddress;
  
  /// Description controller for additional notes
  final TextEditingController? descriptionController;

  const LocationPickerWidget({
    super.key,
    required this.locationMode,
    required this.addressController,
    required this.onLocationSelected,
    this.initialAddress,
    this.editableAddress = false,
    this.descriptionController,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  PlacesService? _placesService;
  List<PlacePrediction> _predictions = [];
  bool _showPredictions = false;
  bool _isLoadingPredictions = false;
  bool _isLoadingLocation = false;
  String? _selectedPlaceId;
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  String? _errorMessage;
  Timer? _debounce;

  // Session token for Places API (reduces costs)
  final String _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    // Don't initialize PlacesService here - dotenv may not be loaded yet
    // It will be initialized lazily when first needed

    // If room mode with initial address, geocode it
    if (widget.locationMode == 'room' && widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      widget.addressController.text = widget.initialAddress!;
      _geocodeInitialAddress(widget.initialAddress!);
    }

    // Listen for address changes to show/hide predictions
    widget.addressController.addListener(_onAddressChanged);
  }

  void _initializePlacesService() {
    if (_placesService == null) {
      try {
        _placesService = PlacesService();
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to initialize location service: $e';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.addressController.removeListener(_onAddressChanged);
    _mapController?.dispose();
    super.dispose();
  }

  /// Handle address text changes - debounced to avoid too many API calls
  void _onAddressChanged() {
    _debounce?.cancel();
    
    // Ensure PlacesService is initialized
    _initializePlacesService();

    if (widget.addressController.text.isEmpty) {
      setState(() {
        _predictions = [];
        _showPredictions = false;
        _errorMessage = null;
      });
      return;
    }

    // Debounce API calls - wait 500ms after user stops typing
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchPredictions(widget.addressController.text);
    });
  }

  /// Fetch autocomplete predictions from Places API
  Future<void> _fetchPredictions(String input) async {
    if (input.isEmpty) return;

    setState(() {
      _isLoadingPredictions = true;
      _errorMessage = null;
    });

    try {
      _initializePlacesService();
      if (_placesService == null) {
        throw 'Location service not initialized. Please check your API key configuration.';
      }

      final predictions = await _placesService!.getAutocompletePredictions(
        input,
        sessionToken: _sessionToken,
      );

      if (mounted) {
        setState(() {
          _predictions = predictions;
          _showPredictions = predictions.isNotEmpty;
          _isLoadingPredictions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isLoadingPredictions = false;
          _predictions = [];
          _showPredictions = false;
        });
      }
    }
  }

  /// When user selects a prediction, get the place details (coordinates)
  Future<void> _selectPrediction(PlacePrediction prediction) async {
    final selectedAddress = prediction.fullDescription;
    widget.addressController.text = selectedAddress;
    _selectedPlaceId = prediction.placeId;

    setState(() {
      _showPredictions = false;
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      _initializePlacesService();
      if (_placesService == null) {
        throw 'Location service not initialized. Please check your API key configuration.';
      }

      final placeDetails = await _placesService!.getPlaceDetails(prediction.placeId);

      if (placeDetails != null && mounted) {
        _updateMapWithLocation(placeDetails);
        
        widget.onLocationSelected(
          LocationPickerResult(
            address: selectedAddress,
            latitude: placeDetails.latitude,
            longitude: placeDetails.longitude,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error getting location: $e';
          _isLoadingLocation = false;
        });
      }
    }
  }

  /// Geocode an address string to get coordinates
  Future<void> _geocodeAddress(String address) async {
    if (address.isEmpty) return;

    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      _initializePlacesService();
      if (_placesService == null) {
        throw 'Location service not initialized. Please check your API key configuration.';
      }

      final result = await _placesService!.geocodeAddress(address);

      if (result != null && mounted) {
        _updateMapWithLocation(result);
        
        widget.onLocationSelected(
          LocationPickerResult(
            address: result.formattedAddress,
            latitude: result.latitude,
            longitude: result.longitude,
          ),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Address not found';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoadingLocation = false;
        });
      }
    }
  }

  /// Initial geocoding when room mode is loaded
  Future<void> _geocodeInitialAddress(String address) async {
    try {
      _initializePlacesService();
      if (_placesService == null) return; // Skip if initialization failed
      
      final result = await _placesService!.geocodeAddress(address);
      if (result != null && mounted) {
        _updateMapWithLocation(result);
      }
    } catch (e) {
      // Silent fail for initial load
    }
  }

  /// Update map with new location
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
      _isLoadingLocation = false;
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

  /// Handle address submit when editing is enabled
  Future<void> _submitAddressEdit() async {
    final address = widget.addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _errorMessage = 'Please enter an address');
      return;
    }

    _geocodeAddress(address);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Address Input Field with Autocomplete
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF5F33E1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: widget.addressController,
                        enabled: widget.locationMode == 'public' || widget.editableAddress,
                        onChanged: (value) {
                          if (widget.locationMode == 'public') {
                            _onAddressChanged();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: widget.locationMode == 'room'
                              ? 'Your room location'
                              : 'Search for a location...',
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF90929C),
                          ),
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                    if (_isLoadingPredictions)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.grey[400]!,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Edit/Submit button for room mode
              if (widget.locationMode == 'room' && widget.editableAddress)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoadingLocation ? null : _submitAddressEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5F33E1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isLoadingLocation ? 'Updating...' : 'Update Location',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

              // Autocomplete Predictions Dropdown
              if (_showPredictions && _predictions.isNotEmpty)
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE8E8E8)),
                    ),
                  ),
                  child: Column(
                    children: _predictions
                        .take(5) // Limit to 5 suggestions
                        .map((prediction) => _buildPredictionTile(prediction))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Error Message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Google Map Display
        if (_selectedLocation != null)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 280,
              child: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation!,
                      zoom: 17.0,
                    ),
                    markers: _markers,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: true,
                    myLocationEnabled: false,
                  ),
                  if (_isLoadingLocation)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Description Field (shown below map)
        if (widget.descriptionController != null)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: widget.descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add additional details about the location...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF90929C),
                ),
                border: InputBorder.none,
              ),
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
      ],
    );
  }

  /// Build a single prediction tile in the dropdown
  Widget _buildPredictionTile(PlacePrediction prediction) {
    return Material(
      child: InkWell(
        onTap: () => _selectPrediction(prediction),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.mainText,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF24252C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (prediction.secondaryText.isNotEmpty)
                      Text(
                        prediction.secondaryText,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Result returned when location is selected
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
