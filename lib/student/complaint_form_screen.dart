import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/location_picker_widget.dart';

class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key});

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationAddressController = TextEditingController();
  final TextEditingController _locationDescriptionController = TextEditingController();

  String? _selectedMaintenanceType;
  String? _selectedUrgency;
  bool _consentGiven = true;

  bool _isSubmitted = false;
  bool _isSubmitting = false;
  bool _isLoadingStudentData = true;
  String? _studentDataError;

  final List<XFile> _pickedImages = [];

  //location
  String? _locationChoice; // "room" or "public"
  Map<String, dynamic>? _studentData; // to store student block/room/college
  GeoPoint? _livingAddressGeoPoint; // to store living address when "Inside My Room" is selected
  
  // Location data from the location picker
  String? _selectedAddress;
  double? _selectedLatitude;
  double? _selectedLongitude;

  final List<String> _maintenanceOptions = ['Furniture', 'Electrical', 'Plumbing', 'Other'];
  final List<String> _urgencyOptions = ['Minor', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationAddressController.dispose();
    _locationDescriptionController.dispose();
    super.dispose();
  }

  /// Fetch student data from Firestore to get college and block info
  Future<void> _fetchStudentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not logged in';

      final studentDoc =
          await FirebaseFirestore.instance.collection('student').doc(user.uid).get();

      if (!studentDoc.exists) throw 'Student record not found';

      if (mounted) {
        setState(() {
          _studentData = studentDoc.data();
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }

  /// Generate initial address for room mode from student data
  String _getInitialRoomAddress() {
    if (_studentData == null) return '';
    
    final college = _studentData?['residentCollege'] ?? '';
    final block = _studentData?['block'] ?? '';
    final room = _studentData?['roomNumber'] ?? '';

    final parts = [college, block, room].where((p) => p.isNotEmpty).toList();
    return parts.join(', ');
  }

  /// Build a card decoration style with shadow and rounded corners
  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
  );

  /// Fetch the student's living address GeoPoint from Firestore
  Future<void> _fetchLivingAddress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final studentDoc = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
      if (studentDoc.exists) {
        final data = studentDoc.data() ?? {};
        final livingAddress = data['livingAddress'] as GeoPoint?;
        
        setState(() {
          _livingAddressGeoPoint = livingAddress;
        });

        if (livingAddress == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Living address not found. Please update your profile.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching living address: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching address: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImages() async {
    if (_pickedImages.length >= 3) return;
    final ImagePicker picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _pickedImages.add(img));
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();

    // Validation
    if (title.isEmpty ||
        desc.isEmpty ||
        _selectedUrgency == null ||
        _selectedMaintenanceType == null ||
        _locationChoice == null ||
        (_locationChoice == "public" && _locationDescriptionController.text.trim().isEmpty) ||
        (_locationChoice == "room" && _livingAddressGeoPoint == null)
    ) {

      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Incomplete'),
          content: Text(
            _locationChoice == "room" && _livingAddressGeoPoint == null
                ? 'Please set your living address in your profile first.'
                : 'Please fill all required fields.'
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not logged in';

      // Ensure student data is loaded
      if (_studentData == null) {
        throw 'Student data not available. Please try again.';
      }

      // Create GeoPoint from coordinates if available
      final repairLocation = (_selectedLatitude != null && _selectedLongitude != null)
          ? GeoPoint(_selectedLatitude!, _selectedLongitude!)
          : null;

      // For room mode: address should be college+block without room number
      // For public mode: description goes to damageLocation, not damageLocationDescription
      final String finalDamageLocation;
      final String finalDamageDescription;
      
      if (_locationChoice == "room") {
        // Room mode: use initial address (college+block)
        finalDamageLocation = _getInitialRoomAddress();
        finalDamageDescription = _locationDescriptionController.text.trim();
      } else {
        // Public area mode: description becomes the damage location
        finalDamageLocation = _locationDescriptionController.text.trim();
        finalDamageDescription = '';
      }

      final complaintData = {
        'assignedTo': '/collection/technician',
        'damageCategory': _selectedMaintenanceType,
        'damagePic': null,
        'damageLocation': finalDamageLocation,
        'repairLocation': repairLocation,
        'damageLocationDescription': finalDamageDescription,
        'damageLocationType': _locationChoice, // 'room' or 'public'
        'feedbackRating': 0,
        'inventoryDamage': desc,
        'inventoryDamageTitle': title,
        'rejectionReason': '',
        'reportBy': '/collection/student/${user.uid}',
        'reportStatus': 'Pending',
        'reportedDate': FieldValue.serverTimestamp(),
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'reviewedBy': '/collection/staff',
        'roomEntryConsent': _consentGiven,
        'scheduledDate': null,
        'technicianTip': 0,
        'urgencyLevel': _selectedUrgency,
        'isRead': false,
        'isArchived': false,
        'studentID': user.uid,
        'statusChangeCount': 1,
      };

      // Add repairLocation (GeoPoint) when "Inside My Room" is selected
      if (_locationChoice == "room" && _livingAddressGeoPoint != null) {
        complaintData['repairLocation'] = _livingAddressGeoPoint;
      }

      final docRef = await firestore.collection('complaint').add(complaintData);

      await docRef.update({'complaintID': docRef.id});

      // Upload images to Cloudinary if any
      if (_pickedImages.isNotEmpty) {
        List<String> cloudinaryUrls = [];
        const cloudName = 'deaju8keu';
        const uploadPreset = 'flutter upload';

        for (int i = 0; i < _pickedImages.length && i < 3; i++) {
          final file = _pickedImages[i];
          Uint8List bytes;

          if (kIsWeb) {
            bytes = await file.readAsBytes();
          } else {
            final rawBytes = await file.readAsBytes();
            final compressed = await FlutterImageCompress.compressWithList(
              rawBytes,
              quality: 70,
            );
            bytes = compressed != null ? compressed : rawBytes;
          }

          final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
          final request = http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = uploadPreset
            ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'complaint_${docRef.id}_$i.jpg'));

          final response = await request.send();
          final resBody = await response.stream.bytesToString();
          final data = json.decode(resBody);
          if (data['secure_url'] != null) cloudinaryUrls.add(data['secure_url']);
        }

        if (cloudinaryUrls.isNotEmpty) await docRef.update({'damagePic': cloudinaryUrls});
      }

      setState(() => _isSubmitted = true);

      if (mounted) {
        _showSuccessDialog('Success!', 'Complaint submitted successfully.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error', 'Failed to submit complaint: $e');
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitButtonText = _isSubmitting ? 'Submitting...' : _isSubmitted ? 'Submitted' : 'Submit Complaint';
    final submitButtonColor = (_isSubmitting || _isSubmitted) ? Colors.grey : const Color(0xFF5F33E1);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        title: Text('Make a Complaint', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Maintenance Type
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                value: _selectedMaintenanceType,
                items: _maintenanceOptions
                    .map((m) => DropdownMenuItem(
                  value: m,
                  child: Text(m, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF24252C))),
                ))
                    .toList(),
                onChanged: (_isSubmitted || _isSubmitting) ? null : (v) => setState(() => _selectedMaintenanceType = v),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Select maintenance type',
                  hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF90929C)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: TextField(
                controller: _titleController,
                enabled: !_isSubmitted && !_isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Fragile bed and missing mattress',
                  hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF90929C)),
                  border: InputBorder.none,
                ),
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF24252C)),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: TextField(
                controller: _descriptionController,
                enabled: !_isSubmitted && !_isSubmitting,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'The bed isn’t in good condition. It’s very shaky and feels like it could collapse if I lie down...',
                  hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF90929C)),
                  border: InputBorder.none,
                ),
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF24252C)),
              ),
            ),
            const SizedBox(height: 16),

            // LOCATION - Mode Selection
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                value: _locationChoice,
                items: const [
                  DropdownMenuItem(value: "room", child: Text("Inside My Room")),
                  DropdownMenuItem(value: "public", child: Text("Public Area")),
                ],
                onChanged: (_isSubmitted || _isSubmitting || _isLoadingStudentData)
                    ? null
                    : (v) {
                        setState(() => _locationChoice = v);
                        // When "Inside My Room" is selected, fetch the living address
                        if (v == "room") {
                          _fetchLivingAddress();
                        }
                      },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Select damage location",
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location Picker Widget (appears only when mode is selected and is public area)
            if (_locationChoice != null && _locationChoice == "public") ...[
              if (_isLoadingStudentData && _locationChoice == "public")
                Container(
                  decoration: _cardDecoration(),
                  padding: const EdgeInsets.all(24),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_studentDataError != null && _locationChoice == "public")
                Container(
                  decoration: _cardDecoration(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error loading student data: $_studentDataError',
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                LocationPickerWidget(
                  locationMode: _locationChoice,
                  addressController: _locationAddressController,
                  initialAddress: _locationChoice == "room" ? _getInitialRoomAddress() : null,
                  editableAddress: _locationChoice == "room",
                  descriptionController: _locationChoice == "public" ? _locationDescriptionController : null,
                  onLocationSelected: (result) {
                    setState(() {
                      _selectedAddress = result.address;
                      _selectedLatitude = result.latitude;
                      _selectedLongitude = result.longitude;
                    });
                  },
                ),
              const SizedBox(height: 16),
            ],

            // ----------------------------------------------------------


            // Image Upload
            GestureDetector(
              onTap: _isSubmitting || _isSubmitted ? null : _pickImages,
              child: Container(
                decoration: _cardDecoration(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Upload picture of report item (Max 3)', style: GoogleFonts.poppins(fontSize: 14))),
                    Text("${_pickedImages.length}/3"),
                    const SizedBox(width: 8),
                    const Icon(Icons.cloud_upload),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Urgency
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                value: _selectedUrgency,
                items: _urgencyOptions
                    .map((u) => DropdownMenuItem(
                  value: u,
                  child: Text(u, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF24252C))),
                ))
                    .toList(),
                onChanged: (_isSubmitted || _isSubmitting) ? null : (v) => setState(() => _selectedUrgency = v),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Select urgency level',
                  hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF90929C)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Consent
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Room Entry Consent', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('I hereby grant permission for authorized staff or technicians to enter my room without my presence...',
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF90929C))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSubmitted || _isSubmitting ? null : () => setState(() => _consentGiven = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: _consentGiven ? const Color(0xFFEDE8FF) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF5F33E1))),
                            child: Text('Yes, I consent', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5F33E1))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSubmitted || _isSubmitting ? null : () => setState(() => _consentGiven = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: !_consentGiven ? const Color(0xFFEDE8FF) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF5F33E1))),
                            child: Text('No, I do not consent',
                                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5F33E1))),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            GestureDetector(
              onTap: _isSubmitted || _isSubmitting ? null : _handleSubmit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: submitButtonColor, borderRadius: BorderRadius.circular(16)),
                child: Text(submitButtonText,
                    textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}