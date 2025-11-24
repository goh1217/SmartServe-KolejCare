import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Category Icons Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CategoryIcon(
                    icon: Icons.home,
                    label: 'Resident\nCollege',
                    color: Colors.pink.shade100,
                    iconColor: Colors.pink,
                  ),
                  _CategoryIcon(
                    icon: Icons.insert_drive_file,
                    label: 'Status\nUpdate',
                    color: Colors.orange.shade100,
                    iconColor: Colors.orange,
                  ),
                  _CategoryIcon(
                    icon: Icons.campaign,
                    label: 'Special\nAnnoucement',
                    color: Colors.blue.shade100,
                    iconColor: Colors.blue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Notification Items
            _NotificationCard(
              icon: Icons.weekend,
              iconColor: Colors.pink,
              iconBgColor: Colors.pink.shade50,
              title: 'Furniture reparation',
              subtitle: 'Level 1',
              time: '10:00 AM',
            ),

            _NotificationCard(
              icon: Icons.hvac,
              iconColor: Colors.orange,
              iconBgColor: Colors.orange.shade50,
              title: 'Ceiling fan damage complaint',
              subtitle: 'Level 1',
              statusText: 'Approved',
              showStatusDot: true,
            ),

            _NotificationCard(
              icon: Icons.build_circle,
              iconColor: Colors.blue,
              iconBgColor: Colors.blue.shade50,
              title: 'Upcoming reparation schedule meeting',
              subtitle: 'Car park, 30 October 2025',
              time: '08:00 PM',
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;

  const _CategoryIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String? time;
  final String? statusText;
  final bool showStatusDot;

  const _NotificationCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.time,
    this.statusText,
    this.showStatusDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Right side (time or status)
          if (time != null)
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  time!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),

          if (statusText != null)
            Row(
              children: [
                if (showStatusDot)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  statusText!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
