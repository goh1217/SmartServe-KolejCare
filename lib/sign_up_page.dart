import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
  final _staffNoController = TextEditingController();
  final _workCollegeController = TextEditingController();

  String? _selectedRole;
  final List<String> _roles = ['student', 'staff', 'technician'];

  String? _selectedMaintenanceField;
  final List<String> _maintenanceFields = ['Electrical', 'Plumbing', 'Furniture', 'HVAC'];

  int? _selectedYear;
  final List<int> _years = [1, 2, 3, 4];

  String? _selectedStaffRank;
  final List<String> _staffRanks = ["supervisor", "manager", "admin", "officer"];

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
        'year': _selectedYear,
        'role': 'student',
        'complaintHistory': [],
        'currentComplaint': [],
        'donationHistory': [],
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
                      decoration: _buildInputDecoration(''),
                      value: _selectedRole,
                      hint: const Text('Choose your role'),
                      isExpanded: true,
                      items: _roles.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value[0].toUpperCase() + value.substring(1)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      },
                      validator: (value) => value == null ? 'Please select a role' : null,
                    ),

                    if (_selectedRole == 'student') ...[
                      const SizedBox(height: 20),
                      _buildLabel('Matric No'),
                      TextFormField(
                        controller: _matricController,
                        decoration: _buildInputDecoration('e.g., A23CS1234'),
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your matric number' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Phone Number'),
                      TextFormField(
                        controller: _phoneController,
                        decoration: _buildInputDecoration('Enter your phone number'),
                        keyboardType: TextInputType.phone,
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Year of Study'),
                      DropdownButtonFormField<int>(
                        decoration: _buildInputDecoration(''),
                        value: _selectedYear,
                        hint: const Text('Choose your year'),
                        isExpanded: true,
                        items: _years.map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(value.toString()),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          setState(() {
                            _selectedYear = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Please select your year of study' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Resident College'),
                      TextFormField(
                        controller: _collegeController,
                        decoration: _buildInputDecoration('Enter your college name(e.g. KTDI)'),
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your college name' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Block'),
                      TextFormField(
                        controller: _blockController,
                        decoration: _buildInputDecoration('e.g., M20'),
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your block' : null,
                      ),
                    ],

                    if (_selectedRole == 'staff') ...[
                      const SizedBox(height: 20),
                      _buildLabel('Staff No'),
                      TextFormField(
                        controller: _staffNoController,
                        decoration: _buildInputDecoration('e.g., STNO001'),
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your staff number' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Phone Number'),
                      TextFormField(
                        controller: _phoneController,
                        decoration: _buildInputDecoration('Enter your phone number'),
                        keyboardType: TextInputType.phone,
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Staff Rank'),
                      DropdownButtonFormField<String>(
                        decoration: _buildInputDecoration(''),
                        value: _selectedStaffRank,
                        hint: const Text('Choose your rank'),
                        isExpanded: true,
                        items: _staffRanks.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value[0].toUpperCase() + value.substring(1)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedStaffRank = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a rank' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Work College'),
                      TextFormField(
                        controller: _workCollegeController,
                        decoration: _buildInputDecoration('Enter your work college'),
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your work college' : null,
                      ),
                    ],

                    if (_selectedRole == 'technician') ...[
                      const SizedBox(height: 20),
                      _buildLabel('Phone Number'),
                      TextFormField(
                        controller: _phoneController,
                        decoration: _buildInputDecoration('Enter your phone number'),
                        keyboardType: TextInputType.phone,
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Maintenance Field'),
                      DropdownButtonFormField<String>(
                        decoration: _buildInputDecoration(''),
                        value: _selectedMaintenanceField,
                        hint: const Text('Choose your specialization'),
                        isExpanded: true,
                        items: _maintenanceFields.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedMaintenanceField = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a specialization' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Monthly Salary'),
                      TextFormField(
                        controller: _salaryController,
                        decoration: _buildInputDecoration('Enter your monthly salary'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter a salary';
                          if (int.tryParse(value) == null) return 'Please enter a valid number';
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 20),
                    _buildLabel('Password'),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _buildInputDecoration('Enter your password').copyWith(
                        suffixIcon: _buildObscureIcon(_obscurePassword, () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        }),
                      ),
                      validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Confirm password'),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: _buildInputDecoration('Re-enter your password').copyWith(
                        suffixIcon: _buildObscureIcon(_obscureConfirmPassword, () {
                          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                        }),
                      ),
                      validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _acceptedTerms,
                            onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              children: [
                                const TextSpan(text: 'I understood the '),
                                TextSpan(
                                  text: 'terms & policy',
                                  style: TextStyle(color: Colors.blue[600], decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()..onTap = () { /* Handle terms */ },
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: const Text(
                                'SIGN UP',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  Widget _buildObscureIcon(bool isObscured, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(
        isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: Colors.grey[600],
        size: 20,
      ),
      onPressed: onPressed,
    );
  }
}
