import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'dart:async';
import '../services/google_geocoding_service.dart';
import 'package:latlong2/latlong.dart' as latlong;

// Type aliases
typedef GoogleLatLng = gmaps.LatLng;

/// Location selection card widget for complaint form
class LocationSelectionCard extends StatefulWidget {
  final String selectedLocation;
  final Function(String, latlong.LatLng?, String?, bool) onLocationChanged;
  final bool isInsideRoom;

  const LocationSelectionCard({
    super.key,
    required this.selectedLocation,
    required this.onLocationChanged,
    required this.isInsideRoom,
  });

  @override
  State<LocationSelectionCard> createState() => _LocationSelectionCardState();
}

class _LocationMapDialog extends StatefulWidget {
  final TextEditingController addressController;
  final TextEditingController descriptionController;
  final latlong.LatLng? initialCoordinates;
  final Function(latlong.LatLng?, String, String) onConfirm;
  final bool isRoom;

  const _LocationMapDialog({
    required this.addressController,
    required this.descriptionController,
    this.initialCoordinates,
    required this.onConfirm,
    required this.isRoom,
  });

  @override
  State<_LocationMapDialog> createState() => _LocationMapDialogState();
}

class _LocationMapDialogState extends State<_LocationMapDialog> {
  late gmaps.GoogleMapController _mapController;
  GoogleLatLng? _currentCoordinates;
  Set<gmaps.Marker> _markers = {};
  Timer? _geocodeTimer;
  List<PlacePrediction> _suggestions = [];
  bool _showSuggestions = false;
  String? _sessionToken;
  late FocusNode _addressFocusNode;

  @override
  void initState() {
    super.initState();
    _currentCoordinates = _initialLatLngFromLatlong(widget.initialCoordinates) ?? const GoogleLatLng(3.1390, 101.6869);
    _updateMarkers();
    _addressFocusNode = FocusNode();
    _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void dispose() {
    _geocodeTimer?.cancel();
    _mapController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  GoogleLatLng? _initialLatLngFromLatlong(latlong.LatLng? latlong) {
    if (latlong == null) return null;
    return GoogleLatLng(latlong.latitude, latlong.longitude);
  }

  latlong.LatLng? _toLatlongLatLng(GoogleLatLng? latlng) {
    if (latlng == null) return null;
    return latlong.LatLng(latlng.latitude, latlng.longitude);
  }

  void _updateMarkers() {
    if (_currentCoordinates != null) {
      _markers = {
        gmaps.Marker(
          markerId: gmaps.MarkerId('location'),
          position: _currentCoordinates!,
          infoWindow: gmaps.InfoWindow(title: 'Selected Location'),
          onTap: () {},
        ),
      };
    }
  }

  Future<void> _onMapTap(GoogleLatLng position) async {
    setState(() {
      _currentCoordinates = position;
      _updateMarkers();
      _showSuggestions = false;
    });

    // Reverse geocode to get address using Google Geocoding
    try {
      final latlongPos = _toLatlongLatLng(position)!;
      final address = await GoogleGeocodingService.reverseGeocode(latlongPos);
      if (address != null && mounted) {
        widget.addressController.text = address;
        print('DEBUG LocationCard: Location geocoded successfully: $latlongPos -> $address');
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }
  }

  Future<void> _getPlacePredictions(String input) async {
    if (input.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      final predictions = await GoogleGeocodingService.getPlacePredictions(
        input.trim(),
        sessionToken: _sessionToken,
        bias: _currentCoordinates != null 
          ? latlong.LatLng(_currentCoordinates!.latitude, _currentCoordinates!.longitude)
          : null,
      );
      
      if (mounted) {
        setState(() {
          _suggestions = predictions;
          _showSuggestions = predictions.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error getting predictions: $e');
    }
  }

  Future<void> _selectPlacePrediction(PlacePrediction prediction) async {
    try {
      final details = await GoogleGeocodingService.getPlaceDetails(
        prediction.placeId,
        sessionToken: _sessionToken,
      );

      if (details != null && mounted) {
        setState(() {
          _currentCoordinates = GoogleLatLng(details.latitude, details.longitude);
          _updateMarkers();
          _showSuggestions = false;
        });

        widget.addressController.text = details.address;

        // Move camera to new location
        await _mapController.animateCamera(
          gmaps.CameraUpdate.newCameraPosition(
            gmaps.CameraPosition(
              target: _currentCoordinates!,
              zoom: 16,
            ),
          ),
        );

        print('DEBUG LocationCard: Place selected: ${details.address}');
      }
    } catch (e) {
      print('Error selecting place: $e');
    }
  }

  Future<void> _geocodeAddress(String address) async {
    if (address.trim().isEmpty) return;

    try {
      final coordinates = await GoogleGeocodingService.geocodeAddress(address.trim());
      if (coordinates != null && mounted) {
        setState(() {
          _currentCoordinates = GoogleLatLng(coordinates.latitude, coordinates.longitude);
          _updateMarkers();
          _showSuggestions = false;
        });
        // Move camera to new location
        await _mapController.animateCamera(
          gmaps.CameraUpdate.newLatLng(_currentCoordinates!),
        );
      }
    } catch (e) {
      print('Error geocoding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isRoom ? 'Adjust Room Location' : 'Enter Public Area Location'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isRoom
                  ? 'Adjust your room location on the map'
                  : 'Enter the location address and description',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.addressController,
              focusNode: _addressFocusNode,
              maxLines: 2,
              readOnly: widget.isRoom,
              decoration: InputDecoration(
                labelText: 'Address',
                hintText: widget.isRoom ? 'Room address (auto-generated)' : 'Search location (Google Maps)',
                border: const OutlineInputBorder(),
                filled: widget.isRoom,
                fillColor: widget.isRoom ? Colors.grey.shade100 : null,
                suffixIcon: _showSuggestions ? Icon(Icons.arrow_drop_down) : null,
              ),
              onChanged: widget.isRoom ? null : (value) async {
                _geocodeTimer?.cancel();
                if (value.trim().isNotEmpty) {
                  _geocodeTimer = Timer(const Duration(milliseconds: 300), () async {
                    await _getPlacePredictions(value.trim());
                  });
                } else {
                  setState(() {
                    _showSuggestions = false;
                    _suggestions = [];
                  });
                }
              },
            ),
            // Show autocomplete suggestions
            if (_showSuggestions && _suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(suggestion.mainText),
                      subtitle: Text(
                        suggestion.secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      onTap: () => _selectPlacePrediction(suggestion),
                      trailing: Icon(Icons.location_on, size: 18, color: Colors.blue),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            if (!widget.isRoom)
              TextField(
                controller: widget.descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (Damage Location Details)',
                  hintText: 'e.g., Near the entrance, second floor',
                  border: OutlineInputBorder(),
                ),
              ),
            if (_currentCoordinates != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                width: 300,
                child: gmaps.GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  initialCameraPosition: gmaps.CameraPosition(
                    target: _currentCoordinates!,
                    zoom: 15,
                  ),
                  markers: _markers,
                  onTap: _onMapTap,
                  compassEnabled: true,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap on map to select location, or drag to move',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_currentCoordinates != null) {
              final latlongCoords = _toLatlongLatLng(_currentCoordinates)!;
              widget.onConfirm(
                latlongCoords,
                widget.addressController.text,
                widget.descriptionController.text,
              );
              print('DEBUG Callback: address=${widget.addressController.text}, coordinates=$latlongCoords, isRoom=${widget.isRoom}');
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a location')),
              );
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _LocationSelectionCardState extends State<LocationSelectionCard> {
  String _manualAddress = '';
  latlong.LatLng? _selectedCoordinates;
  bool _isPublicArea = false;
  bool _isLoadingStudentInfo = false;

  void _showLocationTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Location Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inside My Room'),
              subtitle: const Text('Auto-set from your profile'),
              onTap: () {
                Navigator.pop(context);
                _loadStudentRoomLocation();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Public Area'),
              subtitle: const Text('Manual entry required'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _isPublicArea = true);
                _showMapDialog(isRoom: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadStudentRoomLocation() async {
    setState(() => _isLoadingStudentInfo = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      final studentDoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(user.uid)
          .get();

      if (studentDoc.exists) {
        final data = studentDoc.data() as Map<String, dynamic>;
        final residentCollege = data['residentCollege'] ?? '';
        final block = data['block'] ?? '';
        
        String roomLocation = '';
        if (residentCollege.isNotEmpty && block.isNotEmpty) {
          roomLocation = '$residentCollege $block';
        } else if (residentCollege.isNotEmpty) {
          roomLocation = residentCollege.toString();
        } else if (block.isNotEmpty) {
          roomLocation = block.toString();
        }

        if (roomLocation.isNotEmpty) {
          setState(() {
            _manualAddress = roomLocation;
            _isPublicArea = false;
            _isLoadingStudentInfo = false;
          });

          // Try to geocode the room address to get actual coordinates
          try {
            final latlong.LatLng? roomCoordinates = await GoogleGeocodingService.geocodeAddress(roomLocation);
            
            if (roomCoordinates != null) {
              print('DEBUG LocationCard: Room location geocoded successfully: $roomCoordinates');
              setState(() {
                _selectedCoordinates = roomCoordinates;
              });
              // Notify parent widget of the selected location (passing isRoom=true)
              widget.onLocationChanged(roomLocation, roomCoordinates, roomLocation, true);
            } else {
              print('DEBUG LocationCard: Room location geocoding returned null, using default (Kuala Lumpur)');
              final latlong.LatLng defaultCoordinates = latlong.LatLng(3.1390, 101.6869);
              setState(() {
                _selectedCoordinates = defaultCoordinates;
              });
              widget.onLocationChanged(roomLocation, defaultCoordinates, roomLocation, true);
            }
          } catch (e) {
            print('DEBUG LocationCard: Error geocoding room location: $e');
            // Use default if geocoding fails
            final latlong.LatLng defaultCoordinates = latlong.LatLng(3.1390, 101.6869);
            setState(() {
              _selectedCoordinates = defaultCoordinates;
            });
            widget.onLocationChanged(roomLocation, defaultCoordinates, roomLocation, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room information not found in profile')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading room info: $e')),
      );
    } finally {
      setState(() => _isLoadingStudentInfo = false);
    }
  }

  void _showMapDialog({required bool isRoom}) {
    final addressController = TextEditingController(text: _manualAddress);
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => _LocationMapDialog(
        addressController: addressController,
        descriptionController: descriptionController,
        initialCoordinates: _selectedCoordinates,
        isRoom: isRoom,
        onConfirm: (coordinates, address, description) {
          setState(() {
            _manualAddress = address;
            _selectedCoordinates = coordinates;
            _isPublicArea = !isRoom;
          });

          if (mounted) {
            print('DEBUG LocationCard: Calling onLocationChanged with coordinates: $coordinates, isRoom=$isRoom');
            widget.onLocationChanged(
              address,
              coordinates,
              description.isNotEmpty ? description : address,
              isRoom,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF0EA5E9),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Repair Locator',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !_isPublicArea && _manualAddress.isNotEmpty
                          ? 'Auto-generated room info'
                          : _isPublicArea && _manualAddress.isNotEmpty
                              ? 'Public area location'
                              : 'Select location for repair',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Show loading indicator while fetching room info
          if (_isLoadingStudentInfo)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loading room information...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            )
          // Show success for room location
          else if (!_isPublicArea && _manualAddress.isNotEmpty)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location set to your room',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              _manualAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedCoordinates != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lat: ${_selectedCoordinates!.latitude.toStringAsFixed(4)}, Lng: ${_selectedCoordinates!.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showMapDialog(isRoom: true),
                              icon: const Icon(Icons.map, size: 16),
                              label: const Text('Adjust'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            )
          // Show public area location
          else if (_isPublicArea && _manualAddress.isNotEmpty)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.purple, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Public Area Location',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isPublicArea = false;
                                _manualAddress = '';
                                _selectedCoordinates = null;
                              });
                            },
                            child: const Icon(Icons.close, color: Colors.purple, size: 18),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _manualAddress,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                      if (_selectedCoordinates != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Lat: ${_selectedCoordinates!.latitude.toStringAsFixed(4)}, Lng: ${_selectedCoordinates!.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.purple.withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedCoordinates != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.map, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Map Preview',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showMapDialog(isRoom: false),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Adjust'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            )
          // Show prompt if no location selected yet
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: const Text(
                'Please select a location type - your room will be auto-set, or manually enter a public area',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Location selection button
          if (_manualAddress.isEmpty)
            ElevatedButton(
              onPressed: _showLocationTypeDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3BD6),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Select Location Type'),
            )
          else
            ElevatedButton(
              onPressed: _showLocationTypeDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3BD6),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Change Location'),
            ),
        ],
      ),
    );
  }
}

/// Mixin to enhance complaint form with location features
mixin LocationFormMixin {
  String? repairLocationAddress;
  latlong.LatLng? repairLocationCoordinates;
  bool isLocationInsideRoom = false;

  /// Build the location selection card
  Widget buildLocationSelectionCard(
    BuildContext context,
    bool isInsideRoom,
    Function(String, latlong.LatLng?, String?, bool) onLocationChanged,
  ) {
    return LocationSelectionCard(
      selectedLocation: repairLocationAddress ?? '',
      onLocationChanged: onLocationChanged,
      isInsideRoom: isInsideRoom,
    );
  }

  /// Auto-generate address from room information
  Future<void> autoGenerateRoomAddress(
    String studentId,
    Function(String) onAddressGenerated,
  ) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('student').doc(studentId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final residentCollege = data['residentCollege'] ?? data['block'] ?? '';
        final room = data['room'] ?? '';

        if (residentCollege.isNotEmpty || room.isNotEmpty) {
          final address = '$residentCollege${room.isNotEmpty ? ', Room $room' : ''}';

          repairLocationAddress = address;
          onAddressGenerated(address);
        }
      }
    } catch (e) {
      print('Error generating room address: $e');
    }
  }
}
