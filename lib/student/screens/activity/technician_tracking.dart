import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'phonecall.dart'; // Adjust the path as needed


class TechnicianTrackingScreen extends StatefulWidget {
  final String technicianName;
  final String? complaintId;

  const TechnicianTrackingScreen({super.key, required this.technicianName, this.complaintId});

  @override
  State<TechnicianTrackingScreen> createState() => _TechnicianTrackingScreenState();
}

class _TechnicianTrackingScreenState extends State<TechnicianTrackingScreen> {
  // simulated path points (0..1 space); replace with real lat/lng -> map conversion
  final List<Offset> _path = [
    const Offset(0.2, 0.2),
    const Offset(0.4, 0.18),
    const Offset(0.6, 0.35),
    const Offset(0.75, 0.55),
    const Offset(0.85, 0.7),
  ];
  int _posIndex = 0;
  Timer? _timer;
  String? _studentHostel;
  bool _loadingHostel = false;

  @override
  void initState() {
    super.initState();
    // simulate real-time updates
    _timer = Timer.periodic(const Duration(seconds: 2), (t) {
      setState(() {
        _posIndex = (_posIndex + 1) % _path.length;
      });
    });
    // start loading student hostel location if complaint id provided
    if (widget.complaintId != null) {
      _loadStudentHostel(widget.complaintId!);
    }
  }

  Future<void> _loadStudentHostel(String complaintId) async {
    setState(() {
      _loadingHostel = true;
      _studentHostel = null;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('complaint').doc(complaintId).get();
      if (!doc.exists) {
        setState(() {
          _studentHostel = null;
          _loadingHostel = false;
        });
        return;
      }

      final data = doc.data() ?? {};
      dynamic reportBy = data['reportBy'] ?? data['reportedBy'] ?? data['reporter'] ?? null;
      String? studentId;

      if (reportBy == null) {
        final maybe = data['reportById'] ?? data['reportedById'] ?? data['reporterId'];
        if (maybe != null) studentId = maybe.toString();
      } else if (reportBy is DocumentReference) {
        studentId = reportBy.id;
      } else if (reportBy is String) {
        final s = reportBy as String;
        if (s.contains('/')) {
          final parts = s.split('/').where((p) => p.isNotEmpty).toList();
          if (parts.isNotEmpty) studentId = parts.last;
        } else {
          studentId = s;
        }
      }

      if (studentId != null) {
        final studentDoc = await FirebaseFirestore.instance.collection('student').doc(studentId).get();
        final sdata = studentDoc.data() ?? {};
        // Prefer residentCollege if available (DB uses this field)
        final hostel = (sdata['residentCollege'] ?? sdata['block'] ?? sdata['hostel'] ?? sdata['hostelLocation'] ?? sdata['room'] ?? '').toString();
        setState(() {
          _studentHostel = hostel;
          _loadingHostel = false;
        });
        return;
      }
    } catch (e) {
      // ignore errors
    }

    setState(() {
      _studentHostel = null;
      _loadingHostel = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _path[_posIndex];
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Stack(
        children: [
          // Map area (full screen background)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                // compute marker position in px
                // compute marker position in px (used implicitly by Positioned markers below)
                // final markerX = current.dx * w;
                // final markerY = current.dy * h;
                return Stack(
                  children: [
                    // Map background pattern (simulated)
                    CustomPaint(
                      size: Size(w, h),
                      painter: _MapBackgroundPainter(),
                    ),
                    // path line
                    CustomPaint(
                      size: Size(w, h),
                      painter: _PathPainter(_path, w, h),
                    ),
                    // start marker (purple circle with pin)
                    Positioned(
                      left: _path.first.dx * w - 16,
                      top: _path.first.dy * h - 32,
                      child: const _MapMarker(
                        circleColor: Color(0xFF6B46C1),
                        iconData: Icons.location_pin,
                      ),
                    ),
                    // destination marker (purple circle at end)
                    Positioned(
                      left: _path.last.dx * w - 16,
                      top: _path.last.dy * h - 32,
                      child: const _MapMarker(
                        circleColor: Color(0xFF6B46C1),
                        iconData: Icons.location_pin,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

          // Top App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Technician Tracking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Details Card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text(
                        'Technician Tracking',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Technician Info Row
                      Row(
                        children: [
                          // Avatar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.network(
                              'assets/male.jpg',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, size: 32),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Name and Title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.technicianName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Technician',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Phone Button
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B46C1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () {
                                // Navigate to the PhoneCallScreen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PhoneCallScreen(
                                      technicianName: widget.technicianName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.phone, color: Colors.white, size: 22),
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(),
                            ),
                          ),

                        ],
                      ),

                      const SizedBox(height: 20),

                      // Location Info (student hostel, loaded from complaint -> student)
                      _InfoRow(
                        icon: Icons.location_on,
                        iconColor: const Color(0xFF6B46C1),
                        title: 'Hostel Location',
                        subtitle: _loadingHostel
                            ? ''
                            : (_studentHostel?.isNotEmpty == true ? _studentHostel! : 'Unknown'),
                      ),

                      const SizedBox(height: 16),

                      // ETA Info
                      _InfoRow(
                        icon: Icons.access_time,
                        iconColor: const Color(0xFF6B46C1),
                        title: 'Estimated Arrival Time',
                        subtitle: '',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapMarker extends StatelessWidget {
  final Color circleColor;
  final IconData iconData;
  const _MapMarker({required this.circleColor, required this.iconData});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: Icon(iconData, size: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> path;
  final double w;
  final double h;
  _PathPainter(this.path, this.w, this.h);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final p = Path();
    if (path.isNotEmpty) {
      p.moveTo(path.first.dx * size.width, path.first.dy * size.height);
      for (var pt in path.skip(1)) {
        p.lineTo(pt.dx * size.width, pt.dy * size.height);
      }
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw simple grid to simulate map roads
    for (var i = 0; i < 10; i++) {
      final y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}