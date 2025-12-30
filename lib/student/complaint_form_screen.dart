import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import '../widgets/location_picker_widget.dart'; // Restored GPS Widget

class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key});

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  // --- Controllers (All Restored) ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationAddressController = TextEditingController();
  final TextEditingController _locationDescriptionController = TextEditingController();

  // --- State Variables ---
  String? _selectedMaintenanceType;
  String? _selectedUrgency;
  String? _urgencyLevelAI; // Synced with your latest snippet
  bool _consentGiven = true;
  bool _isSubmitted = false;
  bool _isSubmitting = false;
  bool _isAnalyzing = false;
  bool _isLoadingStudentData = true;

  // --- Images & AI ---
  final List<XFile> _pickedImages = [];
  Interpreter? _interpreter;

  // --- Location/GPS Data ---
  String? _locationChoice;
  Map<String, dynamic>? _studentData;
  GeoPoint? _livingAddressGeoPoint;
  double? _selectedLatitude;
  double? _selectedLongitude;

  final List<String> _maintenanceOptions = ['Furniture', 'Electrical', 'Plumbing', 'Other'];
  final List<String> _urgencyOptions = ['High', 'Medium', 'Minor'];

  @override
  void initState() {
    super.initState();
    _fetchStudentData(); // Restored GPS-related data fetch
    _initModel();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationAddressController.dispose();
    _locationDescriptionController.dispose();
    _interpreter?.close();
    super.dispose();
  }

  // --- AI LOGIC (LOCAL TFLITE - 100% SYNCED) ---

  Future<void> _initModel() async {
    if (kIsWeb) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/urgency_model.tflite');
    } catch (e) {
      debugPrint("Error loading TFLite model: $e");
    }
  }

  Future<void> _classifyImages() async {
    if (_interpreter == null || _pickedImages.isEmpty) return;

    setState(() => _isAnalyzing = true);

    try {
      double totalHigh = 0;
      double totalMedium = 0;
      double totalMinor = 0;

      for (var image in _pickedImages) {
        final imageData = await image.readAsBytes();
        img.Image? decoded = img.decodeImage(imageData);
        if (decoded == null) continue;

        img.Image resized = img.copyResize(decoded, width: 224, height: 224);

        var input = List.generate(1, (i) =>
            List.generate(224, (j) =>
                List.generate(224, (k) =>
                    List.generate(3, (l) => 0.0))));

        for (int y = 0; y < 224; y++) {
          for (int x = 0; x < 224; x++) {
            final pixel = resized.getPixel(x, y);
            // Synced with your specific pixel access logic
            input[0][y][x][0] = pixel.r.toDouble();
            input[0][y][x][1] = pixel.g.toDouble();
            input[0][y][x][2] = pixel.b.toDouble();
          }
        }

        var output = List.filled(1 * 3, 0.0).reshape([1, 3]);
        _interpreter!.run(input, output);

        totalHigh += output[0][0];
        totalMedium += output[0][1];
        totalMinor += output[0][2];
      }

      int count = _pickedImages.length;
      double avgHigh = totalHigh / count;
      double avgMedium = totalMedium / count;
      double avgMinor = totalMinor / count;

      double boostedHigh = avgHigh * 1.5;

      int bestIndex;
      if (boostedHigh >= avgMedium && boostedHigh >= avgMinor) {
        bestIndex = 0; // High
      } else if (avgMedium >= avgMinor) {
        bestIndex = 1; // Medium
      } else {
        bestIndex = 2; // Minor
      }

      setState(() {
        _urgencyLevelAI = _urgencyOptions[bestIndex];
        _selectedUrgency = _urgencyLevelAI;
      });

    } catch (e) {
      debugPrint("Error during multi-image AI: $e");
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // --- GPS / DATA LOGIC ---

  Future<void> _fetchStudentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _studentData = doc.data();
          _isLoadingStudentData = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingStudentData = false);
    }
  }

  Future<void> _fetchLivingAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
    if (doc.exists) {
      setState(() => _livingAddressGeoPoint = doc.data()?['livingAddress'] as GeoPoint?);
    }
  }

  String _getInitialRoomAddress() {
    if (_studentData == null) return '';
    return "${_studentData?['residentCollege'] ?? ''}, ${_studentData?['block'] ?? ''}, ${_studentData?['roomNumber'] ?? ''}";
  }

  Future<void> _pickImages() async {
    if (_pickedImages.length >= 3) return;
    final ImagePicker picker = ImagePicker();
    final XFile? imgFile = await picker.pickImage(source: ImageSource.gallery);

    if (imgFile != null) {
      setState(() => _pickedImages.add(imgFile));
      _classifyImages();
    }
  }

  Future<void> _replaceImage(int index) async {
    if (_isSubmitting) return;
    final ImagePicker picker = ImagePicker();
    final XFile? imgFile = await picker.pickImage(source: ImageSource.gallery);

    if (imgFile != null) {
      setState(() {
        _pickedImages[index] = imgFile;
        _urgencyLevelAI = null; // Reset AI recommendation
      });
      _classifyImages();
    }
  }

  void _deleteImage(int index) {
    if (_isSubmitting) return;
    setState(() {
      _pickedImages.removeAt(index);
      _urgencyLevelAI = null; // Reset AI recommendation
    });
    // Re-run AI if there are still images
    if (_pickedImages.isNotEmpty) {
      _classifyImages();
    }
  }

  // --- SUBMISSION ---

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();

    if (title.isEmpty || desc.isEmpty || _selectedUrgency == null || _locationChoice == null) {
      _showDialog('Incomplete', 'Please fill all required fields.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not logged in';

      final String finalLoc = _locationChoice == "room"
          ? _getInitialRoomAddress()
          : _locationDescriptionController.text.trim();

      // 1. Create the base complaint document
      final docRef = await FirebaseFirestore.instance.collection('complaint').add({
        'damageCategory': _selectedMaintenanceType,
        'damageLocation': finalLoc,
        'repairLocation': _locationChoice == "room" ? _livingAddressGeoPoint : GeoPoint(_selectedLatitude ?? 0, _selectedLongitude ?? 0),
        'inventoryDamage': desc,
        'inventoryDamageTitle': title,
        'reportBy': '/collection/student/${user.uid}',
        'reportStatus': 'Pending',
        'reportedDate': FieldValue.serverTimestamp(),
        'roomEntryConsent': _consentGiven,
        'urgencyLevel': _selectedUrgency,
        'urgencyLevelAI': _urgencyLevelAI,
        'studentID': user.uid,
        'isRead': false,
        'statusChangeCount': 1,
      });

      // 2. Upload images in parallel and wait for ALL to complete
      List<String> cloudinaryUrls = [];
      if (_pickedImages.isNotEmpty) {
        print("DEBUG: Starting upload for ${_pickedImages.length} images.");

        // Map each image to an upload task
        final uploadTasks = _pickedImages.map((file) async {
          final rawBytes = await file.readAsBytes();
          final bytes = kIsWeb ? rawBytes : await FlutterImageCompress.compressWithList(rawBytes, quality: 70) ?? rawBytes;

          final uri = Uri.parse('https://api.cloudinary.com/v1_1/deaju8keu/image/upload');
          final request = http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = 'flutter upload'
            ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'upload.jpg'));

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            final resBody = json.decode(response.body);
            return resBody['secure_url'] as String?;
          } else {
            print("DEBUG: Image upload failed with status ${response.statusCode}");
            return null;
          }
        }).toList();

        // Wait for all tasks to finish
        final results = await Future.wait(uploadTasks);

        // Filter out any nulls (failed uploads)
        cloudinaryUrls = results.whereType<String>().toList();
        print("DEBUG: Successfully uploaded ${cloudinaryUrls.length} out of ${_pickedImages.length} images.");
      }

      // 3. Update the document once with all gathered data
      await docRef.update({
        'damagePic': cloudinaryUrls,
        'complaintID': docRef.id
      });

      setState(() => _isSubmitted = true);
      _showDialog('Success!', 'Complaint submitted successfully.');
    } catch (e) {
      print("DEBUG: Submission Error: $e");
      _showDialog('Error', 'Failed to submit: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showDialog(String title, String content) {
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(content), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
  );

  @override
  Widget build(BuildContext context) {
    final submitButtonColor = (_isSubmitting || _isSubmitted) ? Colors.grey : const Color(0xFF5F33E1);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        title: Text('Make a Complaint', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0,
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
                items: _maintenanceOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: _isSubmitting ? null : (v) => setState(() => _selectedMaintenanceType = v),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select maintenance type'),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: TextField(
                controller: _titleController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter complaint title'),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: TextField(
                controller: _descriptionController,
                enabled: !_isSubmitting,
                maxLines: 5,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Describe the damage details...'),
              ),
            ),
            const SizedBox(height: 16),

            // Location
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                value: _locationChoice,
                items: const [
                  DropdownMenuItem(value: "room", child: Text("Inside My Room")),
                  DropdownMenuItem(value: "public", child: Text("Public Area")),
                ],
                onChanged: (v) {
                  setState(() => _locationChoice = v);
                  if (v == "room") _fetchLivingAddress();
                },
                decoration: const InputDecoration(border: InputBorder.none, hintText: "Select damage location"),
              ),
            ),

            // Restored Map Picker Widget Logic
            if (_locationChoice != null) ...[
              const SizedBox(height: 16),
              LocationPickerWidget(
                locationMode: _locationChoice,
                addressController: _locationAddressController,
                initialAddress: _locationChoice == "room" ? _getInitialRoomAddress() : null,
                editableAddress: _locationChoice == "room",
                descriptionController: _locationDescriptionController,
                onLocationSelected: (result) {
                  setState(() {
                    _selectedLatitude = result.latitude;
                    _selectedLongitude = result.longitude;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),

            // Image Picker
            GestureDetector(
              onTap: _isSubmitting ? null : _pickImages,
              child: Container(
                decoration: _cardDecoration(),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Upload picture (Max 3)', style: GoogleFonts.poppins(fontSize: 14))),
                    Text("${_pickedImages.length}/3"),
                    const SizedBox(width: 8),
                    const Icon(Icons.cloud_upload),
                  ],
                ),
              ),
            ),
            
            // Image Thumbnails
            if (_pickedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                decoration: _cardDecoration(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uploaded Images',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(_pickedImages.length, (index) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? Image.network(
                                        _pickedImages[index].path,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.broken_image);
                                        },
                                      )
                                    : FutureBuilder<Uint8List>(
                                        future: _pickedImages[index].readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            );
                                          }
                                          if (snapshot.hasError || !snapshot.hasData) {
                                            return const Icon(Icons.broken_image);
                                          }
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      ),
                              ),
                            ),
                            // Replace button (tap on image) - placed before delete button
                            // Only covers center area to avoid blocking delete button
                            Positioned(
                              left: 20,
                              right: 20,
                              top: 20,
                              bottom: 20,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _replaceImage(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.transparent,
                                    ),
                                    child: Center(
                                      child: Opacity(
                                        opacity: 0.3, // Subtle hint that image is tappable
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Delete button - placed last so it's on top and clickable
                            Positioned(
                              top: -8,
                              right: -8,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _deleteImage(index),
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // AI Suggestion UI
            if (_isAnalyzing)
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5F33E1))),
                    SizedBox(width: 8),
                    Text("AI is analyzing damage...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )
            else if (_urgencyLevelAI != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF5F33E1)),
                    const SizedBox(width: 6),
                    Text('AI Recommendation: $_urgencyLevelAI',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5F33E1))),
                  ],
                ),
              ),

            // Urgency Dropdown
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                value: _selectedUrgency,
                items: _urgencyOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: _isSubmitting ? null : (v) => setState(() => _selectedUrgency = v),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select urgency level'),
              ),
            ),
            const SizedBox(height: 16),

            // Consent Section
            Container(
              decoration: _cardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading
                  Text('Room Entry Consent',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),

                  // THE RESTORED SUBTEXT
                  Text(
                    'I hereby grant permission for authorized staff or technicians to enter my room without my presence to carry out the necessary repairs based on this report.',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF90929C)),
                  ),
                  const SizedBox(height: 12),

                  // Yes/No Selection Buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSubmitting ? null : () => setState(() => _consentGiven = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: _consentGiven ? const Color(0xFFEDE8FF) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF5F33E1))),
                            child: Text('Yes, I consent',
                                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5F33E1))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSubmitting ? null : () => setState(() => _consentGiven = false),
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

            // Submit Button
            GestureDetector(
              onTap: _isSubmitting ? null : _handleSubmit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: submitButtonColor, borderRadius: BorderRadius.circular(16)),
                child: Text(_isSubmitting ? 'Submitting...' : 'Submit Complaint',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}