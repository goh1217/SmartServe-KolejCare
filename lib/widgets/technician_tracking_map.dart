import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as latlong;
import 'dart:async';
import '../models/location_model.dart';
import '../services/gps_service.dart';
import '../services/google_directions_service.dart';

// Type aliases for clarity
typedef GoogleLatLng = gmaps.LatLng;
typedef GoogleMarker = gmaps.Marker;
typedef GooglePolyline = gmaps.Polyline;

/// Widget for displaying technician tracking with real-time route and ETA using Google Maps
class TechnicianTrackingMap extends StatefulWidget {
  final String technicianId;
  final gmaps.LatLng repairLocation;
  final String studentAddress;

  const TechnicianTrackingMap({
    super.key,
    required this.technicianId,
    required this.repairLocation,
    required this.studentAddress,
  });

  @override
  State<TechnicianTrackingMap> createState() => _TechnicianTrackingMapState();
}

class _TechnicianTrackingMapState extends State<TechnicianTrackingMap> {
  late gmaps.GoogleMapController _mapController;
  LocationData? _technicianLocation;
  RouteData? _routeData;
  bool _isLoadingRoute = false;
  StreamSubscription? _locationSubscription;
  Timer? _routeUpdateTimer;
  Set<GoogleMarker> _markers = {};
  Set<GooglePolyline> _polylines = {};

  // Helper method to convert latlong2.LatLng to google_maps_flutter.LatLng
  GoogleLatLng _toGoogleLatLng(latlong.LatLng latLng) {
    return GoogleLatLng(latLng.latitude, latLng.longitude);
  }

  // Helper method to convert google_maps_flutter.LatLng to latlong2.LatLng
  latlong.LatLng _toLatlongLatLng(GoogleLatLng latLng) {
    return latlong.LatLng(latLng.latitude, latLng.longitude);
  }

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _routeUpdateTimer?.cancel();
    try {
      _mapController.dispose();
    } catch (e) {
      print('[TRACKING MAP] Error disposing map controller: $e');
    }
    super.dispose();
  }

  void _startTracking() {
    print('[TRACKING MAP] _startTracking called');
    print('[TRACKING MAP] Widget repairLocation: ${widget.repairLocation}');
    print('[TRACKING MAP] Widget technicianId: ${widget.technicianId}');
    
    if (widget.technicianId.isEmpty) {
      print('[TRACKING MAP] ERROR: technicianId is empty!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Technician ID not available')),
        );
      }
      return;
    }
    
    // Watch technician location from Firestore - updates in real-time as currentLocation changes
    // The technician app updates currentLocation every 10 seconds
    _locationSubscription = GPSService.watchTechnicianLocation(widget.technicianId)
        .listen(
          (location) {
            print('[TRACKING MAP] Location update: lat=${location.latitude}, lng=${location.longitude}');
            if (mounted) {
              setState(() {
                _technicianLocation = location;
              });
              _fitMapToBounds();
              _updateRoute();
            }
          },
          onError: (e) {
            print('[TRACKING MAP] Error watching technician location: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error tracking location: $e')),
              );
            }
          },
        );

    // Update route every 10 seconds to ensure fresh ETA
    // This aligns with technician's currentLocation update frequency
    _routeUpdateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted && _technicianLocation != null) {
          print('[TRACKING MAP] Periodic route update (10s interval)');
          _updateRoute();
        }
      },
    );

    // Initial route fetch
    print('[TRACKING MAP] Fetching initial route');
    _updateRoute();
  }

  Future<void> _updateRoute() async {
    if (_technicianLocation == null || !mounted) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final techLocation = latlong.LatLng(_technicianLocation!.latitude, _technicianLocation!.longitude);
      
      print('[TRACKING MAP] Requesting route:');
      print('[TRACKING MAP] From (technician): lat=${techLocation.latitude}, lng=${techLocation.longitude}');
      print('[TRACKING MAP] To (repair): lat=${widget.repairLocation.latitude}, lng=${widget.repairLocation.longitude}');
      
      final route = await GoogleDirectionsService.getRoute(
        techLocation,
        _toLatlongLatLng(widget.repairLocation),
      );

      if (route != null) {
        print('[TRACKING MAP] Route received: ${route.distanceKm.toStringAsFixed(1)}km, ${route.durationSeconds.toStringAsFixed(0)}s');
      } else {
        print('[TRACKING MAP] Route is null!');
      }

      if (mounted) {
        setState(() {
          _routeData = route;
          _isLoadingRoute = false;
        });
      }
    } catch (e) {
      print('Error updating route: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  void _fitMapToBounds() {
    if (_technicianLocation == null || !mounted) return;

    try {
      final techLatLng = GoogleLatLng(_technicianLocation!.latitude, _technicianLocation!.longitude);
      
      // Calculate center and zoom level for both points
      final minLat = [techLatLng.latitude, widget.repairLocation.latitude].reduce((a, b) => a < b ? a : b);
      final maxLat = [techLatLng.latitude, widget.repairLocation.latitude].reduce((a, b) => a > b ? a : b);
      final minLng = [techLatLng.longitude, widget.repairLocation.longitude].reduce((a, b) => a < b ? a : b);
      final maxLng = [techLatLng.longitude, widget.repairLocation.longitude].reduce((a, b) => a > b ? a : b);

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      
      _mapController.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: GoogleLatLng(centerLat, centerLng),
            zoom: 14,
          ),
        ),
      );
    } catch (e) {
      print('Error fitting map bounds: $e');
    }
  }

  void _updateMarkers() {
    _markers.clear();
    
    // Technician marker
    if (_technicianLocation != null) {
      _markers.add(
        GoogleMarker(
          markerId: gmaps.MarkerId('technician'),
          position: GoogleLatLng(_technicianLocation!.latitude, _technicianLocation!.longitude),
          infoWindow: gmaps.InfoWindow(title: 'Technician Location'),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Repair location marker
    _markers.add(
      GoogleMarker(
        markerId: gmaps.MarkerId('repair'),
        position: widget.repairLocation,
        infoWindow: gmaps.InfoWindow(title: 'Repair Location'),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
      ),
    );
  }

  void _updatePolylines() {
    _polylines.clear();

    if (_routeData != null && _routeData!.polylinePoints.isNotEmpty) {
      final googleMapPolylines = _routeData!.polylinePoints.map((point) {
        return GoogleLatLng(point.latitude, point.longitude);
      }).toList();

      _polylines.add(
        GooglePolyline(
          polylineId: gmaps.PolylineId('route'),
          color: Colors.blue,
          points: googleMapPolylines,
          width: 4,
        ),
      );
    }
  }


  /// Build the map widget with error handling
  Widget _buildMap() {
    try {
      _updateMarkers();
      _updatePolylines();
      return gmaps.GoogleMap(
        onMapCreated: (gmaps.GoogleMapController controller) {
          _mapController = controller;
          // Fit bounds to show both markers
          _fitMapToBounds();
        },
        initialCameraPosition: gmaps.CameraPosition(
          target: widget.repairLocation,
          zoom: 15,
        ),
        markers: _markers,
        polylines: _polylines,
        zoomControlsEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: true,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        scrollGesturesEnabled: true,
        zoomGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
      );
    } catch (e) {
      print('[TRACKING MAP] Error building map: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Map rendering failed'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error: $e',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Retry
                if (mounted) {
                  setState(() {});
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[TRACKING MAP BUILD] Building TechnicianTrackingMap');
    print('[TRACKING MAP BUILD] technicianLocation: $_technicianLocation');
    print('[TRACKING MAP BUILD] routeData: $_routeData');
    print('[TRACKING MAP BUILD] repairLocation: ${widget.repairLocation}');
    print('[TRACKING MAP BUILD] technicianId: ${widget.technicianId}');
    
    if (widget.technicianId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error: Technician ID is empty'),
              const SizedBox(height: 8),
              Text('techId: "${widget.technicianId}"'),
            ],
          ),
        ),
      );
    }

    // Check if repair location has valid coordinates (not 0,0)
    if (widget.repairLocation.latitude == 0 && widget.repairLocation.longitude == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Location data not available'),
            const SizedBox(height: 8),
            const Text('Repair location has not been set'),
            const SizedBox(height: 16),
            Text('Coordinates: ${widget.repairLocation.latitude}, ${widget.repairLocation.longitude}'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Map - wrapped in SizedBox to ensure it has constraints
        SizedBox.expand(
          child: Container(
            color: Colors.grey[200],
            child: _buildMap(),
          ),
        ),
        // ETA display removed - now shown in technician_location_page green section
        // The map focuses purely on visual tracking
        // Legend at bottom
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Technician Location'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Repair Location'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
