import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  //report sample
  String reportID = 'RPT-20251125-0234';
  String reportStatus = 'Scheduled';
  String scheduledDate = '26 Nov 2025 (Time to be scheduled)';
  String assignedTechnician = 'Ahmad Rahim';
  String damageCategory = 'Bathroom Fixture';
  String inventoryDamage = 'Shower head damage';
  String expectedDuration = '~1 hour 30 minutes';
  String reportedOn = '20 Nov 2025, 12:40 PM';

  bool isCancelled = false;

  bool isEditingDate = false;
  String newScheduledDate = '';

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  void _cancelRequest() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.yellow),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Are you sure you want to cancel your maintenance request?',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        isCancelled = true;
        reportStatus = 'Cancelled'; // Update repair status
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Your request has been cancelled!',
                style: GoogleFonts.poppins(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.poppins())),
          ],
        ),
      );
    }
  }

  void _editOrConfirm() async {
    if (!isEditingDate) {
      DateTime initialDate = DateTime.now();

      try {
        List<String> parts = scheduledDate.split(" ");
        int day = int.parse(parts[0]);
        int month = _monthNumber(parts[1]);
        int year = int.parse(parts[2]);
        initialDate = DateTime(year, month, day);
      } catch (_) {
        initialDate = DateTime.now();
      }

      DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime.now(),
        lastDate: DateTime(DateTime.now().year + 2),
        helpText: 'Select New Scheduled Date',
      );

      if(pickedDate != null){
        setState(() {
          newScheduledDate =
          "${pickedDate.day.toString().padLeft(2, '0')} ${_monthName(pickedDate.month)} ${pickedDate.year} (Time to be scheduled)";
          isEditingDate = true;
        });
      }
    } else {
      setState(() {
        scheduledDate = newScheduledDate;
        isEditingDate = false;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              Text(
                'Your scheduled date has been updated!',
                style: GoogleFonts.poppins(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.poppins())),
          ],
        ),
      );
    }
  }

  int _monthNumber(String shortName) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months.indexOf(shortName);
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  Widget _infoCard(String title, String value) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF90929C))),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complaint Details', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF9F9FB),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _infoCard('ReportID', reportID),
                  _infoCard('Repair Status', reportStatus),
                  _infoCard('Scheduled Date', scheduledDate),
                  _infoCard('Assigned Technician', assignedTechnician),
                  _infoCard('Damage Category', damageCategory),
                  _infoCard('Inventory Damage', inventoryDamage),
                  _infoCard('Expected Duration', expectedDuration),
                  _infoCard('Reported On', reportedOn),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isCancelled ? null : _editOrConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8C7DF5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isEditingDate ? 'Confirm' : 'Edit Request',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isCancelled ? null : _cancelRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA6E6E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Cancel Request',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
