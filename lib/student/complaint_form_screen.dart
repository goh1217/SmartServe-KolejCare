import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key});

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedMaintenanceType;
  String? _selectedUrgency;
  bool _consentGiven = true;

  bool _isSubmitted = false;
  bool _isSubmitting = false;

  final List<XFile> _pickedImages = [];

  final List<String> _maintenanceOptions = ['Furniture', 'Electrical', 'Plumbing', 'Other'];
  final List<String> _urgencyOptions = ['Minor', 'Medium', 'High'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))
    ],
  );

  Future<void> _pickImages() async {
    if (_pickedImages.length >= 3) return;
    final ImagePicker picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _pickedImages.add(img));
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();


    if (title.isEmpty || desc.isEmpty || _selectedUrgency == null || _selectedMaintenanceType == null) {
    showDialog(
    context: context,
    builder: (c) => AlertDialog(
    title: const Text('Incomplete'),
    content: const Text('Please fill all required fields.'),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
    ),
    );
    return;
    }

    setState(() => _isSubmitting = true);

try {
final firestore = FirebaseFirestore.instance;
final user = FirebaseAuth.instance.currentUser;

if (user == null) {
throw 'User not logged in';
}

// Let firestore generate a unique ID
final docRef = await firestore.collection('complaint').add({
'assignedTo': '/collection/technician', //still placeholder
'damageCategory': _selectedMaintenanceType,
'damagePic': null, //still placeholder for future image upload
'feedbackRating': 0,
'inventoryDamage': desc,
'rejectionReason': '',
'reportBy': '/collection/student/${user.uid}', // --- MODIFIED: dynamically set current student ID
'reportStatus': 'Pending',
'reportedDate': FieldValue.serverTimestamp(),
'reviewedBy': '/collection/staff', //still placeholder
'roomEntryConsent': _consentGiven,
'scheduledDate': null,
'technicianTip': 0,
'urgencyLevel': _selectedUrgency,
});

// Get the generated ID and update the document
await docRef.update({'complaintID': docRef.id});

setState(() {
_isSubmitted = true;
});

if (mounted) {
showDialog(
context: context,
builder: (c) => AlertDialog(
title: const Text('Success!'),
content: const Text('Your complaint has been submitted successfully.'),
actions: [
TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
],
),
);
}
} catch (e) {
if (mounted) {
showDialog(
context: context,
builder: (c) => AlertDialog(
title: const Text('Error'),
content: Text('Failed to submit complaint: $e'),
actions: [
TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
],
),
);
}
} finally {
setState(() {
_isSubmitting = false;
});
}
}
// --- END MODIFIED ---

@override
Widget build(BuildContext context) {
String submitButtonText;
Color submitButtonColor;

if (_isSubmitting) {
submitButtonText = 'Submitting...';
submitButtonColor = Colors.grey;
} else if (_isSubmitted) {
submitButtonText = 'Submitted';
submitButtonColor = Colors.grey;
} else {
submitButtonText = 'Submit Complaint';
submitButtonColor = const Color(0xFF5F33E1);
}

return Scaffold(
backgroundColor: const Color(0xFFF9F9FB),
appBar: AppBar(
title: Text('Make a Complaint', style: GoogleFonts.poppins()),
backgroundColor: Colors.white,
foregroundColor: Colors.black87,
elevation: 0,
leading: IconButton(
icon: const Icon(Icons.arrow_back),
onPressed: () => Navigator.pop(context),
),
actions: [
IconButton(
icon: const Icon(Icons.logout),
onPressed: () {
FirebaseAuth.instance.signOut();
},
),
],
),
body: SingleChildScrollView(
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
Container(
decoration: _cardDecoration(),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: DropdownButtonFormField<String>(
value: _selectedMaintenanceType,
items: _maintenanceOptions
    .map(
(m) => DropdownMenuItem(
value: m,
child: Text(
m,
style: GoogleFonts.poppins(
fontSize: 14, color: const Color(0xFF24252C)),
),
),
)
    .toList(),
onChanged: _isSubmitted || _isSubmitting
? null
    : (v) => setState(() => _selectedMaintenanceType = v),
decoration: InputDecoration(
border: InputBorder.none,
hintText: 'Select maintenance type',
hintStyle: GoogleFonts.poppins(
fontSize: 14, color: const Color(0xFF90929C)),
),
),
),
const SizedBox(height: 16),

Container(
decoration: _cardDecoration(),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
child: TextField(
controller: _titleController,
enabled: !_isSubmitted && !_isSubmitting,
decoration: InputDecoration(
hintText: 'Fragile bed and missing mattress',
hintStyle: GoogleFonts.poppins(
fontSize: 14,
color: const Color(0xFF90929C),
),
border: InputBorder.none,
),
style: GoogleFonts.poppins(
fontSize: 14, color: const Color(0xFF24252C)),
),
),
const SizedBox(height: 16),

Container(
decoration: _cardDecoration(),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
child: TextField(
controller: _descriptionController,
enabled: !_isSubmitted && !_isSubmitting,
maxLines: 5,
decoration: InputDecoration(
hintText:
'The bed isn’t in good condition. It’s very shaky and feels like it could collapse if I lie down...',
hintStyle: GoogleFonts.poppins(
fontSize: 14,
color: const Color(0xFF90929C),
),
border: InputBorder.none,
),
style: GoogleFonts.poppins(
fontSize: 14, color: const Color(0xFF24252C)),
),
),
const SizedBox(height: 16),

// Upload picture, not functional yet
Container(
decoration: _cardDecoration(),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
child: Row(
children: [
const Icon(Icons.photo_camera),
const SizedBox(width: 12),
Expanded(
child: Text(
'Upload picture of report item (Max 3)',
style: GoogleFonts.poppins(fontSize: 14),
),
),
const Icon(Icons.cloud_upload),
],
),
),
const SizedBox(height: 16),

Container(
decoration: _cardDecoration(),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: DropdownButtonFormField<String>(
value: _selectedUrgency,
items: _urgencyOptions
    .map(
(u) => DropdownMenuItem(
value: u,
child: Text(
u,
style: GoogleFonts.poppins(
fontSize: 14, color: const Color(0xFF24252C)),
),
),
)
    .toList(),
onChanged: _isSubmitted || _isSubmitting
? null
    : (v) => setState(() => _selectedUrgency = v),
decoration: InputDecoration(
border: InputBorder.none,
hintText: 'Select urgency level',
hintStyle: GoogleFonts.poppins(
fontSize: 14, color: const Color(0xFF90929C)),
),
),
),
const SizedBox(height: 16),

Container(
decoration: _cardDecoration(),
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Room Entry Consent',
style: GoogleFonts.poppins(
fontSize: 16,
fontWeight: FontWeight.w500,
),
),
const SizedBox(height: 8),
Text(
'I hereby grant permission for authorized staff or technicians to enter my room without my presence...',
style: GoogleFonts.poppins(
fontSize: 12, color: const Color(0xFF90929C)),
),
const SizedBox(height: 12),
Row(
children: [
Expanded(
child: GestureDetector(
onTap: _isSubmitted || _isSubmitting
? null
    : () => setState(() => _consentGiven = true),
child: Container(
padding:
const EdgeInsets.symmetric(vertical: 12),
alignment: Alignment.center,
decoration: BoxDecoration(
color: _consentGiven
? const Color(0xFFEDE8FF)
    : Colors.transparent,
borderRadius: BorderRadius.circular(8),
border:
Border.all(color: const Color(0xFF5F33E1)),
),
child: Text(
'Yes, I consent',
style: GoogleFonts.poppins(
fontSize: 14,
color: const Color(0xFF5F33E1),
),
),
),
),
),
const SizedBox(width: 8),
Expanded(
child: GestureDetector(
// --- UPDATED LOGIC TO DISABLE ON SUBMIT ---
onTap: _isSubmitted || _isSubmitting
? null
    : () => setState(() => _consentGiven = false),
child: Container(
padding:
const EdgeInsets.symmetric(vertical: 12),
alignment: Alignment.center,
decoration: BoxDecoration(
color: !_consentGiven
? const Color(0xFFEDE8FF)
    : Colors.transparent,
borderRadius: BorderRadius.circular(8),
border:
Border.all(color: const Color(0xFF5F33E1)),
),
child: Text(
'No, I do not consent',
style: GoogleFonts.poppins(
fontSize: 14,
color: const Color(0xFF5F33E1),
),
),
),
),
),
],
)
],
),
),
const SizedBox(height: 24),

GestureDetector(
onTap: _isSubmitted || _isSubmitting ? null : _handleSubmit,
child: Container(
padding: const EdgeInsets.symmetric(vertical: 16),
decoration: BoxDecoration(
color: submitButtonColor,
borderRadius: BorderRadius.circular(16),
),
child: Text(
submitButtonText,
textAlign: TextAlign.center,
style: GoogleFonts.poppins(
color: Colors.white,
fontSize: 16,
fontWeight: FontWeight.w600,
),
),
),
),
const SizedBox(height: 24),
],
),
),
));
}
}
