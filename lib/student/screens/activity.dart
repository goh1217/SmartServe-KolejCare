import 'package:flutter/material.dart';
import 'activity/ongoingrepair.dart';
import 'activity/completedrepair.dart';
import 'activity/completedrepair2.dart';
import 'activity/completed/rating.dart';
import 'activity/completed/tips.dart';
import 'activity/scheduledrepair.dart';
import 'activity/rejectedrepair.dart';
import 'activity/waitappro.dart';
import 'student_make_complaints.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _selectedIndex = 2; // default to activity tab

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SafeArea(
          child: Container(
            color: const Color(0xFFF5F5F7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: Color(0xFF5E4DB2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Activity',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.notifications, color: Color(0xFF5E4DB2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Ongoing Repairs Section
            _buildSectionCard(
              context,
              title: 'Ongoing Repairs',
              backgroundColor: Colors.transparent,
              items: [
                ActivityItem(
                  title: 'Furniture reparation',
                  status: 'Technician coming',
                  date: '20 Nov 2025, 12:40 PM',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OngoingRepairScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scheduled Section
            _buildSectionCard(
              context,
              title: 'Scheduled',
              backgroundColor: Colors.transparent,
              items: [
                ActivityItem(
                  title: 'Shower head damage',
                  status: 'Scheduled visit',
                  date: '25 Nov 2025, 02:20 PM',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScheduledRepairScreen(
                        reportId: 'RPT-20251125-0234',
                        status: 'Scheduled',
                        scheduledDate: '25 Nov 2025, 10:00 AM',
                        assignedTechnician: 'Ahmad Rahim',
                        damageCategory: 'Bathroom Fixture',
                        inventoryDamage: 'Shower head damage',
                        expectedDuration: '~1 hour 30 minutes',
                        reportedOn: '20 Nov 2025, 12:40 PM',
                        onEditRequest: () {},
                        onCancelRequest: () {},
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Rejected Section
            _buildSectionCard(
              context,
              title: 'Rejected',
              backgroundColor: Colors.transparent,
              items: [
                ActivityItem(
                  title: 'Ceiling fan',
                  status: 'Rejected on',
                  date: '20 Nov 2025, 09:11 AM',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RejectedRepairScreen(
                        status: 'Rejected',
                        damageCategory: 'Ceiling Fan',
                        inventoryDamage: 'The fan rotates too slowly',
                        reportedOn: '19 Nov 2025, 11:58 PM',
                        reviewedOn: '20 Nov 2025, 09:11 AM',
                        reviewedBy: 'Mr. Amirul',
                        rejectionReason: 'The issue is not considered a valid maintenance case. The fan speed is functioning normally based on inspection.',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Waiting Approval Section
            _buildSectionCard(
              context,
              title: 'Waiting Approval',
              backgroundColor: Colors.transparent,
              items: [
                ActivityItem(
                  title: 'Door handle',
                  status: 'Submitted on',
                  date: '23 Nov 2025, 01:58 PM',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WaitingApprovalScreen(
                        reportStatus: 'Waiting to be approved',
                        damageCategory: 'Door handle',
                        inventoryDamage: 'Door handle is loose',
                        reportedOn: '23 Nov 2025, 01:58 PM',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Completed Section
            _buildSectionCard(
              context,
              title: 'Completed Repairs',
              backgroundColor: Colors.transparent,
              items: [
                ActivityItem(
                  title: 'Electric shortage',
                  status: 'Completed on',
                  date: '18 Nov 2025, 01:18 PM',
                  showActions: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CompletedRepairScreen()),
                  ),
                  onRateTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RatingPage()),
                  ),
                  onTipsTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TipsPage()),
                  ),
                ),
                ActivityItem(
                  title: 'Socket damage',
                  status: 'Completed on',
                  date: '9 Oct 2025, 03:20 PM',
                  showActions: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompletedRepair2Screen(
                        reportId: 'RPT-20251009-034',
                        status: 'Completed',
                        completedDate: '9 Oct 2025, 03:20 PM',
                        assignedTechnician: 'Abdul Malim',
                        damageCategory: 'Electrical',
                        inventoryDamage: 'Damaged wall socket',
                        duration: '45 minutes',
                        technicianNotes: 'Removed the damaged socket and installed a new outlet with proper grounding. Tested with voltage meter — all safe and working.',
                        reportedOn: '8 Oct 2025, 10:37 PM',
                      ),
                    ),
                  ),
                  onRateTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RatingPage()),
                  ),
                  onTipsTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TipsPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const MakeComplaintScreen()),
        ),
        backgroundColor: const Color(0xFF5E4DB2),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // replaced old bottom nav with modern rounded BottomAppBar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  /// Bottom Navigation Bar with modern rounded design
  /// Uses ClipRRect for smooth rounded top corners
  Widget _buildBottomNavBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEAE4F9), // Light purple background
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: SizedBox(
            height: 65,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_rounded, 0),
                _buildNavItem(Icons.calendar_today_rounded, 1),
                // Empty space for the central FAB
                const SizedBox(width: 60),
                _buildNavItem(Icons.description_rounded, 2),
                _buildNavItem(Icons.people_rounded, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Individual navigation item with smooth scaling animation
  /// Active state shows darker purple with slight scale effect
  Widget _buildNavItem(IconData icon, int index) {
    final bool isActive = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        // navigate to named routes (ensure these routes exist in main.dart)
        switch (index) {
          case 0:
            Navigator.pushNamed(context, '/home');
            break;
          case 1:
            Navigator.pushNamed(context, '/schedule');
            break;
          case 2:
            Navigator.pushNamed(context, '/reports');
            break;
          case 3:
            Navigator.pushNamed(context, '/chat');
            break;
        }
      },
      child: AnimatedScale(
        scale: isActive ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: isActive
                ? const Color(0xFF6C4DF0) // Darker purple when active
                : const Color(0xFFA18CF0), // Soft purple when inactive
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      BuildContext context, {
        required String title,
        required Color backgroundColor,
        required List<ActivityItem> items,
      }) {
    // Wrap each section in a small margin and a rounded white card.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // optional colored accent strip at the top of the card
                  if (backgroundColor != Colors.transparent)
                    Container(
                      height: 8,
                      color: backgroundColor,
                    ),
                  // section items
                  Column(
                    children: items.map((item) => _buildActivityItem(context, item)).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, ActivityItem item) {
    return InkWell(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(children: [
            Text(item.status, style: const TextStyle(color: Colors.grey)),
            const Spacer(),
            Text(item.date, style: const TextStyle(color: Colors.grey)),
          ]),
          if (item.showActions)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                TextButton.icon(
                  onPressed: item.onRateTap,
                  icon: const Icon(Icons.star_border, size: 16),
                  label: const Text('Rate'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF5E4DB2), padding: EdgeInsets.zero),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: item.onTipsTap,
                  icon: const Icon(Icons.attach_money, size: 16),
                  label: const Text('Tips'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF5E4DB2), padding: EdgeInsets.zero),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class ActivityItem {
  final String title;
  final String status;
  final String date;
  final bool showActions;
  final VoidCallback? onTap;
  final VoidCallback? onRateTap;
  final VoidCallback? onTipsTap;

  ActivityItem({
    required this.title,
    required this.status,
    required this.date,
    this.showActions = false,
    this.onTap,
    this.onRateTap,
    this.onTipsTap,
  });
}