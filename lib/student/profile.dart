import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  String? _profileImageUrl;
  
  // Profile data
  Map<String, dynamic> _profileData = {};
  // which collection/doc we loaded (used for saving)
  String _loadedCollection = 'users';
  String _loadedDocId = '';
  
  // Text controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _matricController;
  late TextEditingController _phoneController;
  late TextEditingController _genderController;
  late TextEditingController _collegeController;
  late TextEditingController _blockController;
  late TextEditingController _roomController;
  late TextEditingController _wingController;
  late TextEditingController _addressSearchController;
  
  // Location picker state
  GeoPoint? _selectedLivingAddress;
  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _isSearchingAddress = false;
  bool _isLoadingAddressSuggestions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeControllers();
    _fetchProfileData();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _matricController = TextEditingController();
    _phoneController = TextEditingController();
    _genderController = TextEditingController();
    _collegeController = TextEditingController();
    _blockController = TextEditingController();
    _roomController = TextEditingController();
    _wingController = TextEditingController();
    _addressSearchController = TextEditingController();
  }

  Future<void> _fetchProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      Map<String, dynamic>? data;
      String collection = 'users';
      String docId = widget.userId;

      // 1) If widget.userId is provided, try users/{userId}
      if (widget.userId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
        if (doc.exists && (doc.data() ?? {}).isNotEmpty) {
          data = doc.data() as Map<String, dynamic>;
          collection = 'users';
          docId = widget.userId;
        }
      }

      // 2) If not found, try to find student doc by authUid
      if (data == null && authUser != null) {
        final q = await FirebaseFirestore.instance.collection('student').where('authUid', isEqualTo: authUser.uid).limit(1).get();
        if (q.docs.isNotEmpty) {
          data = q.docs.first.data();
          collection = 'student';
          docId = q.docs.first.id;
        }
      }

      // 3) If still not found, try student by email
      if (data == null && authUser != null && (authUser.email?.isNotEmpty == true)) {
        final q = await FirebaseFirestore.instance.collection('student').where('email', isEqualTo: authUser.email).limit(1).get();
        if (q.docs.isNotEmpty) {
          data = q.docs.first.data();
          collection = 'student';
          docId = q.docs.first.id;
        }
      }

      // 4) final fallback: if widget.userId provided, try student/{userId}
      if (data == null && widget.userId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('student').doc(widget.userId).get();
        if (doc.exists) {
          data = doc.data() as Map<String, dynamic>;
          collection = 'student';
          docId = widget.userId;
        }
      }

      if (data != null) {
        setState(() {
          _profileData = data!;
          _loadedCollection = collection;
          _loadedDocId = docId;
          _updateControllers();
          _isLoading = false;
        });
      } else {
        // not found: clear fields
        setState(() {
          _profileData = {};
          _loadedCollection = 'users';
          _loadedDocId = widget.userId;
          _updateControllers();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateControllers() {
    _nameController.text = _profileData['studentName'] ?? '';
    _emailController.text = _profileData['email'] ?? '';
    _matricController.text = _profileData['matricNo'] ?? '';
    _phoneController.text = _profileData['phoneNo'] ?? '';
    _genderController.text = _profileData['gender'] ?? '';
    _collegeController.text = _profileData['residentCollege'] ?? '';
    _blockController.text = _profileData['block'] ?? '';
    _roomController.text = _profileData['roomNumber'] ?? '';
    _wingController.text = _profileData['wing'] ?? '';
    _profileImageUrl = _profileData['photoUrl'] ?? _profileData['profilePic'] ?? null;
    _selectedLivingAddress = _profileData['livingAddress'] as GeoPoint?;
    if (_selectedLivingAddress != null) {
      _addressSearchController.text = 'Lat: ${_selectedLivingAddress!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLivingAddress!.longitude.toStringAsFixed(4)}';
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    if (!_isEditing) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      setState(() => _isUploadingPhoto = true);

      Uint8List bytes;
      if (kIsWeb) {
        bytes = await file.readAsBytes();
      } else {
        final raw = await file.readAsBytes();
        bytes = await FlutterImageCompress.compressWithList(raw, quality: 70);
      }

      const cloudName = 'deaju8keu';
      const uploadPreset = 'flutter upload';
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'profile_upload.jpg'));

      final streamed = await req.send();
      final res = await streamed.stream.bytesToString();
      final data = json.decode(res);
      final String? url = data['secure_url'];

      if (url != null) {
        setState(() {
          _profileImageUrl = url;
        });

        // Persist immediately so it shows next time even if user doesn't press Save
        final targetCollection = _loadedCollection.isNotEmpty ? _loadedCollection : 'users';
        final targetDocId = _loadedDocId.isNotEmpty ? _loadedDocId : widget.userId;
        if (targetDocId.isNotEmpty) {
          await FirebaseFirestore.instance.collection(targetCollection).doc(targetDocId).set({'photoUrl': url}, SetOptions(merge: true));
        }
      }
    } catch (e) {
      if (kDebugMode) print('Profile image upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  /// Search for addresses using OpenStreetMap Nominatim API
  Future<void> _searchAddresses(String query) async {
    if (query.isEmpty) {
      setState(() {
        _addressSuggestions = [];
        _isSearchingAddress = false;
      });
      return;
    }

    setState(() => _isLoadingAddressSuggestions = true);

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5',
        ),
        headers: {'User-Agent': 'SmartServe-Flutter-App'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _addressSuggestions = data
              .map((item) => {
                    'name': item['display_name'] ?? '',
                    'lat': double.tryParse(item['lat'].toString()) ?? 0.0,
                    'lng': double.tryParse(item['lon'].toString()) ?? 0.0,
                  })
              .toList();
          _isSearchingAddress = true;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Address search error: $e');
      setState(() {
        _addressSuggestions = [];
        _isSearchingAddress = true;
      });
    } finally {
      setState(() => _isLoadingAddressSuggestions = false);
    }
  }

  /// Select an address and set the GeoPoint
  void _selectAddress(Map<String, dynamic> suggestion) {
    setState(() {
      _selectedLivingAddress = GeoPoint(suggestion['lat'], suggestion['lng']);
      _addressSearchController.text = suggestion['name'];
      _addressSuggestions = [];
      _isSearchingAddress = false;
    });
  }

  Future<void> _saveChanges() async {
    try {
      final targetCollection = _loadedCollection.isNotEmpty ? _loadedCollection : 'users';
      final targetDocId = _loadedDocId.isNotEmpty ? _loadedDocId : widget.userId;
      if (targetDocId.isEmpty) throw Exception('No document id available to save profile');

      final updateData = {
        'studentName': _nameController.text,
        'email': _emailController.text,
        'matricNo': _matricController.text,
        'phoneNo': _phoneController.text,
        'gender': _genderController.text,
        'residentCollege': _collegeController.text,
        'block': _blockController.text,
        'roomNumber': _roomController.text,
        'wing': _wingController.text,
        'photoUrl': _profileImageUrl ?? _profileData['photoUrl'],
      };

      // Add livingAddress if it has been set
      if (_selectedLivingAddress != null) {
        updateData['livingAddress'] = _selectedLivingAddress;
      }

      await FirebaseFirestore.instance
          .collection(targetCollection)
          .doc(targetDocId)
          .set(updateData, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );

      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _matricController.dispose();
    _phoneController.dispose();
    _genderController.dispose();
    _collegeController.dispose();
    _blockController.dispose();
    _roomController.dispose();
    _wingController.dispose();
    _addressSearchController.dispose();
    super.dispose();
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            enabled: _isEditing,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[600]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Profile' : 'Profile',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.close : Icons.edit,
              color: Colors.black,
            ),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  _updateControllers(); // Reset changes
                }
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                          ? NetworkImage(_profileImageUrl!) as ImageProvider
                          : null,
                      child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploadingPhoto ? null : _pickAndUploadProfileImage,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.indigo,
                            child: _isUploadingPhoto
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tabs
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.indigo,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.indigo,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'General'),
                      Tab(text: 'Location'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // General Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildProfileField(
                          label: 'Full Name',
                          controller: _nameController,
                          icon: Icons.person_outline,
                        ),
                        _buildProfileField(
                          label: 'Email',
                          controller: _emailController,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _buildProfileField(
                          label: 'Matric Number',
                          controller: _matricController,
                          icon: Icons.tag,
                        ),
                        _buildProfileField(
                          label: 'Phone Number',
                          controller: _phoneController,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        // Faculty field removed
                        _buildProfileField(
                          label: 'Gender',
                          controller: _genderController,
                          icon: Icons.people_outline,
                        ),
                      ],
                    ),
                  ),
                ),
                // Location Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildProfileField(
                          label: 'Residential College',
                          controller: _collegeController,
                          icon: Icons.apartment,
                        ),
                        _buildProfileField(
                          label: 'Block',
                          controller: _blockController,
                          icon: Icons.business,
                        ),
                        _buildProfileField(
                          label: 'Room Number',
                          controller: _roomController,
                          icon: Icons.meeting_room,
                        ),
                        _buildProfileField(
                          label: 'Wing',
                          controller: _wingController,
                          icon: Icons.location_on_outlined,
                        ),
                        // Address Search Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Living Address (GPS Location)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!_isEditing)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedLivingAddress != null
                                            ? 'Lat: ${_selectedLivingAddress!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLivingAddress!.longitude.toStringAsFixed(4)}'
                                            : 'No address set',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      controller: _addressSearchController,
                                      onChanged: _searchAddresses,
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(Icons.location_on, color: Colors.grey[600]),
                                        hintText: 'Search for address...',
                                        hintStyle: TextStyle(color: Colors.grey[500]),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_isLoadingAddressSuggestions)
                                    Positioned(
                                      right: 16,
                                      top: 12,
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            if (_isSearchingAddress && _addressSuggestions.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _addressSuggestions.length,
                                  itemBuilder: (context, index) {
                                    final suggestion = _addressSuggestions[index];
                                    return ListTile(
                                      leading: const Icon(Icons.location_on, size: 18, color: Colors.grey),
                                      title: Text(
                                        suggestion['name'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onTap: () => _selectAddress(suggestion),
                                    );
                                  },
                                ),
                              ),
                            if (_selectedLivingAddress != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Address selected: Lat ${_selectedLivingAddress!.latitude.toStringAsFixed(4)}, Lng ${_selectedLivingAddress!.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isEditing
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C28D9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}