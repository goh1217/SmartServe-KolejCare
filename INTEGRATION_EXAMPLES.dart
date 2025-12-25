// Example of how to integrate location selection into the complaint form

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';
import '../widgets/location_selection_card.dart';
import '../services/osrm_service.dart';

/// Example integration of location selection in complaint form
/// Add this to your existing student_make_complaints.dart file

class ComplaintFormWithLocationExample extends StatefulWidget {
  const ComplaintFormWithLocationExample({super.key});

  @override
  State<ComplaintFormWithLocationExample> createState() =>
      _ComplaintFormWithLocationExampleState();
}

class _ComplaintFormWithLocationExampleState
    extends State<ComplaintFormWithLocationExample> {
  // Existing form fields
  String selectedMaintenanceType = 'Furniture';
  String inventoryDamage = '';
  String description = '';
  String urgencyLevel = 'Minor';
  bool consentGranted = false;

  // New location fields
  String? repairLocationAddress;
  LatLng? repairLocationCoordinates;
  bool isLocationInsideRoom = false;
  String studentId = ''; // Get from Firebase Auth or context

  @override
  void initState() {
    super.initState();
    // Optional: Auto-detect if complaint is about room
  }

  /// Handle location selection from the location card
  void _onLocationChanged(
      String address, LatLng? coordinates, String? displayAddress, bool isRoom) {
    setState(() {
      repairLocationAddress = address;
      repairLocationCoordinates = coordinates;
      isLocationInsideRoom = isRoom;
    });
  }

  /// Auto-generate room address
  Future<void> _autoGenerateRoomAddress() async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(studentId)
          .get();

      if (studentDoc.exists) {
        final data = studentDoc.data() as Map<String, dynamic>;
        final residentCollege = data['residentCollege'] ?? data['block'] ?? '';
        final room = data['room'] ?? '';
        final block = data['block'] ?? '';

        final generatedAddress = '$residentCollege${block.isNotEmpty ? ', $block' : ''}${room.isNotEmpty ? ', Room $room' : ''}';

        setState(() {
          repairLocationAddress = generatedAddress;
          isLocationInsideRoom = true;
        });

        // Optional: Geocode the generated address
        try {
          final coordinates =
              await OSRMService.geocodeAddress(generatedAddress);
          setState(() {
            repairLocationCoordinates = coordinates;
          });
        } catch (e) {
          print('Could not geocode generated address: $e');
        }
      }
    } catch (e) {
      print('Error auto-generating room address: $e');
    }
  }

  /// Submit complaint with location data
  Future<void> _submitComplaintWithLocation() async {
    if (!consentGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant room entry consent')),
      );
      return;
    }

    if (repairLocationAddress == null || repairLocationAddress!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location for repair')),
      );
      return;
    }

    try {
      // Build the damage location data
      final damageLocationData = {
        'address': repairLocationAddress,
        'latitude': repairLocationCoordinates?.latitude ?? 0.0,
        'longitude': repairLocationCoordinates?.longitude ?? 0.0,
        'type': isLocationInsideRoom ? 'room' : 'public_area',
      };

      // Submit to Firestore
      await FirebaseFirestore.instance.collection('complaint').add({
        'damageCategory': selectedMaintenanceType,
        'inventoryDamage': inventoryDamage,
        'description': description,
        'urgencyLevel': urgencyLevel,
        'damageLocation': damageLocationData,
        'reportedDate': Timestamp.now(),
        'reportStatus': 'PENDING',
        'roomEntryConsent': consentGranted,
        // ... other fields ...
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complaint submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Complaint'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Existing form fields (maintenance type, damage, etc.)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Maintenance Type',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedMaintenanceType,
                      isExpanded: true,
                      items: ['Furniture', 'Civil', 'Electric']
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedMaintenanceType = value ?? 'Furniture';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location selection card - NEW
            LocationSelectionCard(
              selectedLocation: repairLocationAddress ?? '',
              onLocationChanged: _onLocationChanged,
              isInsideRoom: isLocationInsideRoom,
            ),
            const SizedBox(height: 16),

            // Quick button to auto-generate room address
            if (!isLocationInsideRoom)
              ElevatedButton.icon(
                onPressed: _autoGenerateRoomAddress,
                icon: const Icon(Icons.home),
                label: const Text('Use Room Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                ),
              ),
            const SizedBox(height: 24),

            // Submit button
            ElevatedButton(
              onPressed: _submitComplaintWithLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3BD6),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Submit Complaint',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example of reading location data from complaint
class ComplaintViewerExample extends StatefulWidget {
  final String complaintId;

  const ComplaintViewerExample({super.key, required this.complaintId});

  @override
  State<ComplaintViewerExample> createState() =>
      _ComplaintViewerExampleState();
}

class _ComplaintViewerExampleState extends State<ComplaintViewerExample> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('complaint')
          .doc(widget.complaintId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final damageLocationData = data['damageLocation'] as Map?;

        String address = 'Unknown Location';
        double latitude = 0.0;
        double longitude = 0.0;
        String locationType = 'unknown';

        if (damageLocationData != null) {
          address = damageLocationData['address'] ?? address;
          latitude = (damageLocationData['latitude'] ?? 0.0) as double;
          longitude = (damageLocationData['longitude'] ?? 0.0) as double;
          locationType = damageLocationData['type'] ?? 'unknown';
        }

        return Column(
          children: [
            ListTile(
              title: const Text('Location Type'),
              subtitle: Text(locationType == 'room' ? 'Room' : 'Public Area'),
            ),
            ListTile(
              title: const Text('Address'),
              subtitle: Text(address),
            ),
            ListTile(
              title: const Text('Coordinates'),
              subtitle: Text('$latitude, $longitude'),
            ),
          ],
        );
      },
    );
  }
}
