import 'package:flutter/material.dart';
import 'package:owtest/assign_technician.dart';
import 'package:owtest/staff_complaints.dart';

class ComplaintDetailsPage extends StatelessWidget {
  final Complaint complaint;

  const ComplaintDetailsPage({Key? key, required this.complaint}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(complaint.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Student: ${complaint.student}'),
            Text('Room: ${complaint.room}'),
            Text('Category: ${complaint.category}'),
            Text('Priority: ${complaint.priority}'),
            Text('Status: ${complaint.status.toString().split('.').last}'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AssignTechnicianPage(complaint: complaint)),
                );
              },
              child: const Text('Reassign Technician'),
            ),
          ],
        ),
      ),
    );
  }
}
