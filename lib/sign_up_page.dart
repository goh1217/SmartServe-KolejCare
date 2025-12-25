import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _salaryController = TextEditingController();
  final _matricController = TextEditingController();
  final _collegeController = TextEditingController();
  final _blockController = TextEditingController();
  final _roomController = TextEditingController();
  final _staffNoController = TextEditingController();
  final _workCollegeController = TextEditingController();
  final _livingAddressController = TextEditingController();

  // Living address location for student
  GeoPoint? _livingAddressGeoPoint;

  String? _selectedRole;
  final List<String> _roles = ['student', 'staff', 'technician'];

  String? _selectedMaintenanceField;
  final List<String> _maintenanceFields = ['Electrical', 'Plumbing', 'Furniture', 'HVAC'];

  int? _selectedYear;
  final List<int> _years = [1, 2, 3, 4];

  String? _selectedStaffRank;
  final List<String> _staffRanks = ["supervisor", "manager", "admin", "officer"];

  // Gender and wing for student
  String? _selectedGender;
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  String? _selectedWing;
  final List<String> _wingOptions = ['A', 'B', 'C'];

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  Future<bool> _isMatricNoUnique(String matricNo) async {
    if (matricNo.isEmpty) return true; // Validator will handle empty case
    final result = await FirebaseFirestore.instance
        .collection('student')
        .where('matricNo', isEqualTo: matricNo)
        .limit(1)
        .get();
    return result.docs.isEmpty;
  }

  Future<bool> _isStaffNoUnique(String staffNo) async {
    if (staffNo.isEmpty) return true;
    final result = await FirebaseFirestore.instance
        .collection('staff')
        .where('staffNo', isEqualTo: staffNo)
        .limit(1)
        .get();
    return result.docs.isEmpty;
  }

  /// Search for address and convert to GeoPoint using Google Geocoding API
  Future<void> _searchAddress(String address) async {
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an address'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final geocodingKey = dotenv.env['GEOCODING_API_KEY'] ?? '';
      if (geocodingKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geocoding API key not configured'), backgroundColor: Colors.red),
        );
        return;
      }

      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$geocodingKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['status'] == 'OK' && json['results'] != null && json['results'].isNotEmpty) {
          final result = json['results'][0];
          final location = result['geometry']['location'];
          
          setState(() {
            _livingAddressGeoPoint = GeoPoint(location['lat'], location['lng']);
            _livingAddressController.text = result['formatted_address'];
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Address found successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Address not found. Please check and try again.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        throw Exception('Geocoding API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching address: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'By creating an account, you agree to the following terms and our Privacy Policy.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 16),
              Text('1. User Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('You are responsible for maintaining the confidentiality of your account and for all activities that occur under your account. You must provide accurate and complete information.'),
              SizedBox(height: 12),
              Text('2. User Conduct', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('You agree to use the SmartServe platform only for lawful purposes. You will not submit false, misleading, or malicious information, including fraudulent damage reports.'),
              SizedBox(height: 12),
              Text('3. Data & Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('We collect personal data such as your name, email, and contact details to provide our services. We also collect information related to your complaints and reports to manage and resolve them effectively. We do not sell your data. We may share it with university staff or technicians solely for resolving your issues.'),
              SizedBox(height: 12),
              Text('4. Termination', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('We reserve the right to suspend or terminate your account at our discretion if you violate these terms, without prior notice.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Check if student has verified their address
    if (_selectedRole == 'student' && _livingAddressGeoPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and verify your address'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must accept the terms and policy.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedRole == 'student') {
        final isUnique = await _isMatricNoUnique(_matricController.text.trim());
        if (!isUnique) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Matric number already exists.'), backgroundColor: Colors.red),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      } else if (_selectedRole == 'staff') {
        final isUnique = await _isStaffNoUnique(_staffNoController.text.trim());
        if (!isUnique) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Staff number already exists.'), backgroundColor: Colors.red),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await _createFirestoreUserDocument(userCredential.user!, _selectedRole!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign-up successful!'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else {
        message = 'An error occurred. Please try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createFirestoreUserDocument(User user, String role) async {
    final firestore = FirebaseFirestore.instance;

    if (role == 'technician') {
      final techCollection = firestore.collection('technician');
      String newTechnicianNo;
      final querySnapshot = await techCollection.orderBy('technicianNo', descending: true).limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        newTechnicianNo = 'TN0001';
      } else {
        final lastTechnicianNo = querySnapshot.docs.first.data()['technicianNo'] as String;
        final lastNumber = int.parse(lastTechnicianNo.substring(2));
        newTechnicianNo = 'TN${(lastNumber + 1).toString().padLeft(4, '0')}';
      }

      Map<String, dynamic> userData = {
        'technicianName': _nameController.text.trim(),
        'technicianNo': newTechnicianNo,
        'email': user.email,
        'phoneNo': _phoneController.text.trim(),
        'maintenanceField': _selectedMaintenanceField,
        'monthlySalary': int.tryParse(_salaryController.text.trim()) ?? 0,
        'role': 'technician',
        'availability': true,
        'tasksAssigned': [],
        'uid': user.uid,
      };
      await techCollection.add(userData);
    } else if (role == 'student') {
      final studentCollection = firestore.collection('student');
      Map<String, dynamic> studentData = {
        'studentName': _nameController.text.trim(),
        'matricNo': _matricController.text.trim(),
        'email': user.email,
        'phoneNo': _phoneController.text.trim(),
        'residentCollege': _collegeController.text.trim(),
        'block': _blockController.text.trim(),
        'roomNumber': _roomController.text.trim(),
        'gender': _selectedGender ?? '',
        'wing': _selectedWing ?? '',
        'year': _selectedYear,
        'role': 'student',
        'complaintHistory': [],
        'currentComplaint': [],
        'donationHistory': [],
        'livingAddress': _livingAddressGeoPoint,
        'uid': user.uid,
      };
      await studentCollection.doc(user.uid).set(studentData);
    } else if (role == 'staff') {
      final staffCollection = firestore.collection('staff');
      Map<String, dynamic> staffData = {
        'staffName': _nameController.text.trim(),
        'staffNo': _staffNoController.text.trim(),
        'email': user.email,
        'phoneNo': _phoneController.text.trim(),
        'staffRank': _selectedStaffRank,
        'workCollege': _workCollegeController.text.trim(),
        'role': 'staff',
        'assignedComplaints': [],
        'uid': user.uid,
      };
      await staffCollection.doc(user.uid).set(staffData);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _matricController.dispose();
    _collegeController.dispose();
    _blockController.dispose();
    _staffNoController.dispose();
    _workCollegeController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[800]),
        titleTextStyle: TextStyle(color: Colors.grey[800], fontSize: 18, fontWeight: FontWeight.w500),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'S',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SmartServe',
                          style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Create your account',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 32),
                    _buildLabel('Full Name'),
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration('Enter your full name'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Email'),
                    TextFormField(
                      controller: _emailController,
                      decoration: _buildInputDecoration('Enter your email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Select Role'),
                    DropdownButtonFormField<String>(
                      decoration: _buildInputDecoration('Select your role'),
                      value: _selectedRole,
                      items: _roles.map((role) {
                        return DropdownMenuItem(value: role, child: Text(role[0].toUpperCase() + role.substring(1)));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedRole = value),
                      validator: (value) => value == null ? 'Please select a role' : null,
                    ),
                    if (_selectedRole != null) ..._buildRoleSpecificFields(),
                    const SizedBox(height: 20),
                    _buildLabel('Password'),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _buildInputDecoration('Enter your password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Confirm Password'),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: _buildInputDecoration('Confirm your password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _acceptedTerms,
                            onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              children: [
                                const TextSpan(text: 'I have read and agree to the '),
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold),
                                  recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                    const SizedBox(height: 24),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold),
                            recognizer: TapGestureRecognizer()..onTap = () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRoleSpecificFields() {
    switch (_selectedRole) {
      case 'student':
        return [
          const SizedBox(height: 20),
          _buildLabel('Matric No'),
          TextFormField(
            controller: _matricController,
            decoration: _buildInputDecoration('Enter your matric number'),
            validator: (value) => value == null || value.isEmpty ? 'Please enter your matric number' : null,
          ),
          const SizedBox(height: 20),
          _buildLabel('Resident College'),
          TextFormField(
            controller: _collegeController,
            decoration: _buildInputDecoration('Enter your college name'),
            validator: (value) => value == null || value.isEmpty ? 'Please enter your college' : null,
          ),
          const SizedBox(height: 20),
          _buildLabel('Living Address'),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _livingAddressController,
                  decoration: _buildInputDecoration('Search your address'),
                  validator: (value) => value == null || value.isEmpty ? 'Please enter your living address' : null,
                  onChanged: (_) {
                    // Clear geopoint if user edits the address
                    if (_livingAddressGeoPoint != null) {
                      setState(() => _livingAddressGeoPoint = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Colors.blue),
                  onPressed: () => _searchAddress(_livingAddressController.text.trim()),
                  tooltip: 'Search address',
                ),
              ),
            ],
          ),
          if (_livingAddressGeoPoint != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Address verified',
                        style: TextStyle(color: Colors.green[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ];
      case 'staff':
        return [
          const SizedBox(height: 20),
          _buildLabel('Staff No'),
          TextFormField(
            controller: _staffNoController,
            decoration: _buildInputDecoration('Enter your staff number'),
            validator: (value) => value == null || value.isEmpty ? 'Please enter your staff number' : null,
          ),
          const SizedBox(height: 20),
          _buildLabel('Staff Rank'),
          DropdownButtonFormField<String>(
            decoration: _buildInputDecoration('Select staff rank'),
            value: _selectedStaffRank,
            items: _staffRanks.map((rank) {
              return DropdownMenuItem(
                value: rank,
                child: Text(rank[0].toUpperCase() + rank.substring(1)),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedStaffRank = value),
            validator: (value) => value == null ? 'Please select a staff rank' : null,
          ),
          const SizedBox(height: 20),
          _buildLabel('Work College / Department'),
          TextFormField(
            controller: _workCollegeController,
            decoration: _buildInputDecoration('Enter your work college or department'),
            validator: (value) => value == null || value.isEmpty ? 'This field is required' : null,
          ),
        ];
      case 'technician':
        return [
          const SizedBox(height: 20),
          _buildLabel('Maintenance Field'),
          DropdownButtonFormField<String>(
            decoration: _buildInputDecoration('Select maintenance field'),
            value: _selectedMaintenanceField,
            items: _maintenanceFields.map((field) {
              return DropdownMenuItem(value: field, child: Text(field));
            }).toList(),
            onChanged: (value) => setState(() => _selectedMaintenanceField = value),
            validator: (value) => value == null ? 'Please select a field' : null,
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          text,
          style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.blue[600]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
