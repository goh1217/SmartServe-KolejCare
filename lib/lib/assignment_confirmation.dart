import 'package:flutter/material.dart';
import 'package:owtest/staff_complaints.dart';

class AssignmentConfirmationPage extends StatelessWidget {
  const AssignmentConfirmationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            const Text('Technician Assigned Successfully', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const StaffComplaintsPage()));
              },
              child: const Text('Back to Complaints'),
            ),
          ],
        ),
      ),
    );
  }
}
