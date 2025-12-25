import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../services/osrm_service.dart';
import 'package:latlong2/latlong.dart' as latlong;

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

class _LocationSelectionCardState extends State<LocationSelectionCard> {
  @override
  Widget build(BuildContext context) {
    return SizedBox.shrink();
  }
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
  late GoogleMapController _mapController;
  LatLng? _currentCoordinates;
  Set<Marker> _markers = {};
  Timer? _geocodeTimer;

  @override
  void initState() {
    super.initState();
    // Default to Kuala Lumpur if no coordinates
    _currentCoordinates = _initialLatLngFromLatlong(widget.initialCoordinates) ?? const LatLng(3.1390, 101.6869);
    _updateMarkers();
  }

  @override
  void dispose() {
    _geocodeTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  LatLng? _initialLatLngFromLatlong(latlong.LatLng? latlong) {
    if (latlong == null) return null;
    return LatLng(latlong.latitude, latlong.longitude);
  }

  latlong.LatLng? _toLatlongLatLng(LatLng latlng) {
    return latlong.LatLng(latlng.latitude, latlng.longitude);
  }

  void _updateMarkers() {
    if (_currentCoordinates != null) {
      _markers = {
        Marker(
          markerId: const MarkerId('location'),
          position: _currentCoordinates!,
          infoWindow: const InfoWindow(title: 'Selected Location'),
          onTap: () {},
        ),
      };
    }
  }

  Future<void> _onMapTap(LatLng position) async {
    setState(() {
      _currentCoordinates = position;
      _updateMarkers();
    });

    // Reverse geocode to get address
    try {
      final latlongPos = _toLatlongLatLng(position)!;
      final address = await OSRMService.reverseGeocode(latlongPos);
      if (address != null && mounted) {
        widget.addressController.text = address;
        print('DEBUG LocationCard: Room location geocoded successfully: $latlongPos');
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }
  }

  Future<void> _geocodeAddress(String address) async {
    if (address.trim().isEmpty) return;

    try {
      final coordinates = await OSRMService.geocodeAddress(address.trim());
      if (coordinates != null && mounted) {
        setState(() {
          _currentCoordinates = LatLng(coordinates.latitude, coordinates.longitude);
          _updateMarkers();
        });
        // Move camera to new location
        await _mapController.animateCamera(
          CameraUpdate.newLatLng(_currentCoordinates!),
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
              maxLines: 2,
              readOnly: widget.isRoom,
              decoration: InputDecoration(
                labelText: 'Address',
                hintText: widget.isRoom ? 'Room address (auto-generated)' : 'e.g., Library Main Hall',
                border: const OutlineInputBorder(),
                filled: widget.isRoom,
                fillColor: widget.isRoom ? Colors.grey.shade100 : null,
              ),
              onChanged: widget.isRoom ? null : (value) async {
                _geocodeTimer?.cancel();
                if (value.trim().isNotEmpty) {
                  _geocodeTimer = Timer(const Duration(milliseconds: 500), () async {
                    await _geocodeAddress(value.trim());
                  });
                }
              },
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
                child: GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentCoordinates!,
                    zoom: 15,
                  ),
                  markers: _markers,
                  onTap: _onMapTap,
                  compassEnabled: true,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap on map to select location',
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
