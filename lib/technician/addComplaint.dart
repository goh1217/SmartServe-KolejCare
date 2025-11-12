import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'firebase_service.dart';

// ==================== AI Category Predictor ====================

class CategoryPredictor {
  late Interpreter _interpreter;
  late Map<String, dynamic> _tokenizer;
  late Map<int, String> _labelMap;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('text_classifier.tflite');
    _tokenizer = json.decode(await rootBundle.loadString('assets/tokenizer.json'));
    _labelMap =
    Map<int, String>.from(json.decode(await rootBundle.loadString('assets/label_map.json')));
    _isLoaded = true;
    print("✅ Model loaded successfully!");
  }

  Future<String> predictCategory(String text) async {
    if (!_isLoaded) throw Exception("Model not loaded yet!");
    text = text.toLowerCase();

    final words = text.split(' ');
    final vocab = Map<String, dynamic>.from(_tokenizer['config']['word_index']);
    final sequence = words.map((w) => vocab[w] ?? 1).toList();

    // Pad sequence
    const maxLen = 20;
    final padded = List.filled(maxLen, 0);
    for (int i = 0; i < sequence.length && i < maxLen; i++) {
      padded[i] = sequence[i];
    }

    var input = [padded];
    var output = List.filled(_labelMap.length, 0.0).reshape([1, _labelMap.length]);
    _interpreter.run(input, output);

    int predictedIndex = output[0].indexOf(output[0].reduce((a, b) => a > b ? a : b));
    return _labelMap[predictedIndex] ?? "Unknown";
  }
}

// ==================== MAIN PAGE ====================

class AddComplaintPage extends StatefulWidget {
  const AddComplaintPage({super.key});

  @override
  State<AddComplaintPage> createState() => _AddComplaintPageState();
}

class _AddComplaintPageState extends State<AddComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime? _selectedDate;
  double _duration = 1;
  String? _category;
  List<XFile> _images = [];
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  final String technicianId = 'technicianId'; // 🔧 Replace later if needed

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images = picked.take(3).toList();
      });
    }
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields and select a date')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ MATCH EXACT STRUCTURE from existing tasks
      final taskData = {
        'Assignment notes': '',
        'Category': _category ?? 'Uncategorized',
        'Description': _descController.text.trim(),
        'StudentId': 'TBD',
        'complaint': _titleController.text.trim(),
        'location': 'M17 KTDI',
        'priority': 'Medium',
        'scheduleDate': Timestamp.fromDate(_selectedDate!),
        'status': 'In Progress',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 🔥 Add inside nested path: technician/{id}/tasks/{autoID}
      final docRef = await FirebaseFirestore.instance
          .collection('technician')
          .doc(technicianId)
          .collection('tasks')
          .add(taskData);

      await docRef.update({'taskId': docRef.id});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Complaint added successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print("❌ Error uploading complaint: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Complaint'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Complaint Title', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'Enter complaint title'),
                validator: (v) => v == null || v.isEmpty ? 'Please enter title' : null,
              ),
              const SizedBox(height: 16),

              const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Describe the issue'),
                validator: (v) => v == null || v.isEmpty ? 'Please enter description' : null,
              ),
              const SizedBox(height: 16),

              const Text('Category'),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Furniture', child: Text('Furniture')),
                  DropdownMenuItem(value: 'Civil', child: Text('Civil')),
                  DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                ],
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Select a category' : null,
              ),
              const SizedBox(height: 16),

              const Text('Schedule Date'),
              Row(
                children: [
                  Text(_selectedDate == null
                      ? 'No date selected'
                      : _selectedDate.toString().split(' ')[0]),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Text('Duration (hours): '),
                  Expanded(
                    child: Slider(
                      value: _duration,
                      min: 1,
                      max: 8,
                      divisions: 7,
                      label: '${_duration.round()}h',
                      onChanged: (v) => setState(() => _duration = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Attach Images (optional)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var img in _images)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.file(File(img.path), height: 100, width: 100, fit: BoxFit.cover),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => setState(() => _images.remove(img)),
                        ),
                      ],
                    ),
                  if (_images.length < 3)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        height: 100,
                        width: 100,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.add_a_photo, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 30),

              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                  ),
                  onPressed: _isLoading ? null : _submitTask,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Complaint', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}