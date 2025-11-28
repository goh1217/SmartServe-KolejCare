import 'dart:async';
import 'package:flutter/material.dart';

// Twilio code removed. This is a placeholder screen to avoid build errors.
class PhoneCallScreen extends StatefulWidget {
  final String? technicianName; // <-- added parameter
  const PhoneCallScreen({super.key, this.technicianName});

  @override
  State<PhoneCallScreen> createState() => _PhoneCallScreenState();
}

class _PhoneCallScreenState extends State<PhoneCallScreen> {
  @override
  Widget build(BuildContext context) {
    final name = widget.technicianName ?? 'Technician';
    return Scaffold(
      appBar: AppBar(title: Text('Call: $name')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_disabled, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Phone/VoIP features are disabled in this build.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Technician: $name',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}