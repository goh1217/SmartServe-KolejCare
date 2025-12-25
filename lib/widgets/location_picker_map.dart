import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';
import '../services/google_geocoding_service.dart';

/// Widget for picking location on a map
class LocationPickerMap extends StatefulWidget {
  final Function(LatLng, String?) onLocationSelected;
  final LatLng? initialLocation;

  const LocationPickerMap({
    super.key,
    required this.onLocationSelected,
    this.initialLocation,
  });

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  late MapController _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = newLocation;
      });

      _mapController.move(newLocation, 17);
      _getReverseGeocode(newLocation);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _getReverseGeocode(LatLng location) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final address = await GoogleGeocodingService.reverseGeocode(location);
      setState(() {
        _selectedAddress = address;
        _isLoadingAddress = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation ?? const LatLng(3.1390, 101.6869),
              initialZoom: 15,
              onTap: (tapPosition, point) async {
                setState(() {
                  _selectedLocation = point;
                });
                await _getReverseGeocode(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              // Selected location marker
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_on,
                        color: Colors.red[600],
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Current location button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'current_location',
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          // Address display and confirm button
          if (_selectedLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Latitude: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Longitude: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingAddress)
                      const SizedBox(
                        height: 20,
                        child: LinearProgressIndicator(),
                      )
                    else if (_selectedAddress != null)
                      Text(
                        _selectedAddress!,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      )
                    else
                      const Text(
                        'Unable to fetch address',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onLocationSelected(
                          _selectedLocation!,
                          _selectedAddress,
                        );
                      },
                      child: const Text('Confirm Location'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
