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
import '../widgets/location_picker_widget.dart';

class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key});

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  // --- Controllers ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationAddressController = TextEditingController();
  final TextEditingController _locationDescriptionController = TextEditingController();

  // --- State Variables ---
  String? _selectedMaintenanceType;
  String? _selectedUrgency;
  String? _urgencyLevelAI;
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
    _fetchStudentData();
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

  // --- AI LOGIC ---
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
      double totalHigh = 0; double totalMedium = 0; double totalMinor = 0;
      for (var image in _pickedImages) {
        final imageData = await image.readAsBytes();
        img.Image? decoded = img.decodeImage(imageData);
        if (decoded == null) continue;
        img.Image resized = img.copyResize(decoded, width: 224, height: 224);
        var input = List.generate(1, (i) => List.generate(224, (j) => List.generate(224, (k) => List.generate(3, (l) => 0.0))));
        for (int y = 0; y < 224; y++) {
          for (int x = 0; x < 224; x++) {
            final pixel = resized.getPixel(x, y);
            input[0][y][x][0] = pixel.r.toDouble();
            input[0][y][x][1] = pixel.g.toDouble();
            input[0][y][x][2] = pixel.b.toDouble();
          }
        }
        var output = List.filled(1 * 3, 0.0).reshape([1, 3]);
        _interpreter!.run(input, output);
        totalHigh += output[0][0]; totalMedium += output[0][1]; totalMinor += output[0][2];
      }
      int count = _pickedImages.length;
      double avgHigh = totalHigh / count; double avgMedium = totalMedium / count; double avgMinor = totalMinor / count;
      double boostedHigh = avgHigh * 1.5;
      int bestIndex = (boostedHigh >= avgMedium && boostedHigh >= avgMinor) ? 0 : (avgMedium >= avgMinor ? 1 : 2);
      setState(() {
        _urgencyLevelAI = _urgencyOptions[bestIndex];
        _selectedUrgency = _urgencyLevelAI;
      });
    } catch (e) { debugPrint("AI Error: $e"); }
    finally { setState(() => _isAnalyzing = false); }
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
    } catch (e) { setState(() => _isLoadingStudentData = false); }
  }

  Future<void> _fetchLivingAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      final livingAddress = data['livingAddress'] as GeoPoint?;
      setState(() => _livingAddressGeoPoint = livingAddress);

      // IMMEDIATE ORANGE FEEDBACK
      if (livingAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Living address not found. Please update your profile.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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

  void _deleteImage(int index) {
    if (_isSubmitting) return;
    setState(() {
      _pickedImages.removeAt(index);
      _urgencyLevelAI = null;
    });
    if (_pickedImages.isNotEmpty) _classifyImages();
  }

  // --- SUBMISSION ---
  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();

    // Validation exactly from original code
    if (title.isEmpty || desc.isEmpty || _selectedUrgency == null || _locationChoice == null ||
        (_locationChoice == "room" && _livingAddressGeoPoint == null)) {
      _showDialog(
          'Incomplete',
          _locationChoice == "room" && _livingAddressGeoPoint == null
              ? 'Please set your living address in your profile first.'
              : 'Please fill all required fields.'
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not logged in';

      final String finalLoc = _locationChoice == "room" ? _getInitialRoomAddress() : _locationDescriptionController.text.trim();

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
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      List<String> cloudinaryUrls = [];
      if (_pickedImages.isNotEmpty) {
        final uploadTasks = _pickedImages.map((file) async {
          final rawBytes = await file.readAsBytes();
          final bytes = kIsWeb ? rawBytes : await FlutterImageCompress.compressWithList(rawBytes, quality: 70) ?? rawBytes;
          final uri = Uri.parse('https://api.cloudinary.com/v1_1/deaju8keu/image/upload');
          final request = http.MultipartRequest('POST', uri)..fields['upload_preset'] = 'flutter upload'..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'upload.jpg'));
          final response = await http.Response.fromStream(await request.send());
          return response.statusCode == 200 ? json.decode(response.body)['secure_url'] as String? : null;
        }).toList();
        final results = await Future.wait(uploadTasks);
        cloudinaryUrls = results.whereType<String>().toList();
      }

      await docRef.update({'damagePic': cloudinaryUrls, 'complaintID': docRef.id});
      setState(() => _isSubmitted = true);
      _showDialog('Success!', 'Complaint submitted successfully.');
    } catch (e) { _showDialog('Error', 'Failed: $e'); }
    finally { setState(() => _isSubmitting = false); }
  }

  void _showDialog(String title, String content) {
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(content), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
  }

  BoxDecoration _cardDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]);

  @override
  Widget build(BuildContext context) {
    final submitButtonColor = (_isSubmitting || _isSubmitted) ? Colors.grey : const Color(0xFF5F33E1);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(title: Text('Make a Complaint', style: GoogleFonts.poppins()), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(decoration: _cardDecoration(), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: DropdownButtonFormField<String>(value: _selectedMaintenanceType, items: _maintenanceOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: _isSubmitting ? null : (v) => setState(() => _selectedMaintenanceType = v), decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select maintenance type'))),
            const SizedBox(height: 16),
            Container(decoration: _cardDecoration(), padding: const EdgeInsets.all(16), child: TextField(controller: _titleController, enabled: !_isSubmitting, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter complaint title'))),
            const SizedBox(height: 16),
            Container(decoration: _cardDecoration(), padding: const EdgeInsets.all(16), child: TextField(controller: _descriptionController, enabled: !_isSubmitting, maxLines: 5, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Describe the damage details...'))),
            const SizedBox(height: 16),

            Container(decoration: _cardDecoration(), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: DropdownButtonFormField<String>(value: _locationChoice, items: const [DropdownMenuItem(value: "room", child: Text("Inside My Room")), DropdownMenuItem(value: "public", child: Text("Public Area"))],
                onChanged: (_isSubmitting) ? null : (v) {
                  setState(() => _locationChoice = v);
                  if (v == "room") _fetchLivingAddress();
                },
                decoration: const InputDecoration(border: InputBorder.none, hintText: "Select damage location"))),
            const SizedBox(height: 16),

            if (_locationChoice != null && _locationChoice == "public") ...[
              LocationPickerWidget(locationMode: _locationChoice, addressController: _locationAddressController, initialAddress: null, editableAddress: true, descriptionController: _locationDescriptionController, onLocationSelected: (result) {
                setState(() { _selectedLatitude = result.latitude; _selectedLongitude = result.longitude; });
              }),
              const SizedBox(height: 16),
            ],

            GestureDetector(onTap: _isSubmitting ? null : _pickImages, child: Container(decoration: _cardDecoration(), padding: const EdgeInsets.all(16), child: Row(children: [const Icon(Icons.photo_camera), const SizedBox(width: 12), Expanded(child: Text('Upload picture (Max 3)', style: GoogleFonts.poppins(fontSize: 14))), Text("${_pickedImages.length}/3")]))),

            if (_pickedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 12, children: _pickedImages.asMap().entries.map((e) => Stack(children: [
                Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: kIsWeb ? Image.network(e.value.path, fit: BoxFit.cover) : FutureBuilder<Uint8List>(future: e.value.readAsBytes(), builder: (context, snapshot) {
                      return snapshot.hasData ? Image.memory(snapshot.data!, fit: BoxFit.cover) : const Center(child: CircularProgressIndicator());
                    }))),
                Positioned(top: -5, right: -5, child: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _deleteImage(e.key)))] )).toList()),
            ],
            const SizedBox(height: 12),

            if (_isAnalyzing) const Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text("AI analyzing...", style: TextStyle(fontSize: 12))])
            else if (_urgencyLevelAI != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('AI Recommendation: $_urgencyLevelAI', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5F33E1)))),

            Container(decoration: _cardDecoration(), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: DropdownButtonFormField<String>(value: _selectedUrgency, items: _urgencyOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: _isSubmitting ? null : (v) => setState(() => _selectedUrgency = v), decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select urgency level'))),
            const SizedBox(height: 16),

            Container(decoration: _cardDecoration(), padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Room Entry Consent', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text('I hereby grant permission for authorized staff or technicians to enter my room without my presence to carry out the necessary repairs based on this report.', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF90929C))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: GestureDetector(onTap: () => setState(() => _consentGiven = true), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(color: _consentGiven ? const Color(0xFFEDE8FF) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF5F33E1))), child: Text('Yes', style: GoogleFonts.poppins(color: const Color(0xFF5F33E1)))))),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(onTap: () => setState(() => _consentGiven = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(color: !_consentGiven ? const Color(0xFFEDE8FF) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF5F33E1))), child: Text('No', style: GoogleFonts.poppins(color: const Color(0xFF5F33E1))))))
              ])
            ])),
            const SizedBox(height: 24),

            GestureDetector(onTap: _isSubmitting ? null : _handleSubmit, child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: submitButtonColor, borderRadius: BorderRadius.circular(16)), child: Text(_isSubmitting ? 'Submitting...' : 'Submit Complaint', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }
}