import 'package:flutter/material.dart';
import 'package:owtest/analytics_page.dart';
import 'package:owtest/assignment_confirmation.dart';
import 'package:owtest/help_page.dart';
import 'package:owtest/staff_complaints.dart';

class AssignTechnicianPage extends StatefulWidget {
  final Complaint complaint;

  const AssignTechnicianPage({Key? key, required this.complaint}) : super(key: key);

  @override
  _AssignTechnicianPageState createState() => _AssignTechnicianPageState();
}

class _AssignTechnicianPageState extends State<AssignTechnicianPage> {
  final List<String> _technicians = ['Muhammad Ali', 'Qamarul Ahmad', 'Lee Wei Wei', 'Ruben'];
  String? _selectedTechnician;
  String? _selectedPriority;
  final _notesController = TextEditingController();

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const StaffComplaintsPage()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsPage()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        backgroundColor: const Color(0xFF6D28D9),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign Technician', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Text('Select Technician', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Choose a technician'),
              value: _selectedTechnician,
              onChanged: (value) => setState(() => _selectedTechnician = value),
              items: _technicians.map((technician) {
                return DropdownMenuItem(value: technician, child: Text(technician));
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Priority Level', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Priority Level'),
              value: _selectedPriority,
              onChanged: (value) => setState(() => _selectedPriority = value),
              items: ['Low', 'Medium', 'High'].map((priority) {
                return DropdownMenuItem(value: priority, child: Text(priority));
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Assignment Notes', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Any special instructions for the technician',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AssignmentConfirmationPage()),
                  );
                },
                child: const Text('Assign'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0000FF), // Blue color for the button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            )
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Complaints'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.help), label: 'Help'),
        ],
        currentIndex: 1,
        selectedItemColor: const Color(0xFF7C3AED),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
