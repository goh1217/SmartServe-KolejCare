import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _staffData;
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _phoneNoController;
  late TextEditingController _staffNameController;

  @override
  void initState() {
    super.initState();
    _phoneNoController = TextEditingController();
    _staffNameController = TextEditingController();
    _fetchStaffDetails();
  }

  Future<void> _fetchStaffDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();

      if (mounted && querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        setState(() {
          _staffData = data;
          _phoneNoController.text = data['phoneNo'] ?? '';
          _staffNameController.text = data['staffName'] ?? '';
        });
      }
    } catch (e) {
      print("Error fetching staff details: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading staff data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    setState(() => _isSaving = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('staff')
            .doc(docId)
            .update({
          'phoneNo': _phoneNoController.text,
          'staffName': _staffNameController.text,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // Refresh data
          _fetchStaffDetails();
        }
      }
    } catch (e) {
      print("Error saving changes: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _staffData == null
                      ? const Center(
                          child: Text('No staff data found'),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildSectionTitle('Staff Information'),
                            const SizedBox(height: 16),
                            _buildEmailField(),
                            const SizedBox(height: 16),
                            _buildEditableField(
                              label: 'Staff Name',
                              controller: _staffNameController,
                              isEditable: true,
                            ),
                            const SizedBox(height: 16),
                            _buildEditableField(
                              label: 'Phone Number',
                              controller: _phoneNoController,
                              isEditable: true,
                            ),
                            const SizedBox(height: 16),
                            _buildReadOnlyField(
                              label: 'Staff No',
                              value: _staffData!['staffNo'] ?? 'N/A',
                            ),
                            const SizedBox(height: 16),
                            _buildReadOnlyField(
                              label: 'Staff Rank',
                              value: _staffData!['staffRank'] ?? 'N/A',
                            ),
                            const SizedBox(height: 16),
                            _buildReadOnlyField(
                              label: 'Work College',
                              value: _staffData!['workCollege'] ?? 'N/A',
                            ),
                            const SizedBox(height: 32),
                            _buildSaveButton(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Icon(Icons.settings, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildEmailField() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              FirebaseAuth.instance.currentUser?.email ?? 'N/A',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool isEditable,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              enabled: isEditable,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                filled: !isEditable,
                fillColor: !isEditable ? Colors.grey[100] : Colors.white,
              ),
              style: TextStyle(
                fontSize: 16,
                color: isEditable ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneNoController.dispose();
    _staffNameController.dispose();
    super.dispose();
  }
}
