import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<_ComplaintNotification> notifications = [];
  bool isLoading = true;
  
  // Stream subscriptions for real-time updates
  final List<StreamSubscription> _subscriptions = [];
  String? _studentDocId;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    // Mark all as read when entering the page after a delay
    _markAllAsReadOnEnter();
  }

  Future<void> _markAllAsReadOnEnter() async {
    // Wait 2 seconds so user can see unread notifications first
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && notifications.isNotEmpty) {
      await _markAllAsRead(showSnackbar: false);
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions when leaving the page
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _setupRealtimeListeners() async {
    setState(() {
      isLoading = true;
      notifications = [];
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      _currentUid = uid;
      
      if (uid == null) {
        setState(() => isLoading = false);
        return;
      }

      // Find student doc id using UID from student collection
      final studentQuery = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
          
      if (studentQuery.docs.isNotEmpty) {
        _studentDocId = studentQuery.docs.first.id;
      } else {
        final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        if (userEmail.isNotEmpty) {
          final byEmail = await FirebaseFirestore.instance
              .collection('student')
              .where('email', isEqualTo: userEmail)
              .limit(1)
              .get();
          if (byEmail.docs.isNotEmpty) {
            _studentDocId = byEmail.docs.first.id;
          }
        }
      }

      if (_studentDocId != null && _studentDocId!.isNotEmpty) {
        _listenToComplaints();
      }

      setState(() => isLoading = false);
    } catch (e) {
      if (kDebugMode) print('Error setting up listeners: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _listenToComplaints() {
    if (_studentDocId == null) return;

    final sid = _studentDocId!;
    
    // The exact format: /collection/student/uid
    final exactPath = '/collection/student/$sid';

    // Main listener for the exact path format
    final subscription = FirebaseFirestore.instance
        .collection('complaint')
        .where('reportBy', isEqualTo: exactPath)
        .snapshots()
        .listen((snapshot) {
      if (kDebugMode) {
        print('=== Real-time Update Received ===');
        print('Found ${snapshot.docs.length} complaints');
      }

      if (snapshot.docs.isNotEmpty) {
        final List<_ComplaintNotification> items = [];
        
        for (var doc in snapshot.docs) {
          final notif = _mapDocToNotification(doc);
          items.add(notif);
        }
        
        // Sort by creation time (newest first)
        items.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
        
        if (mounted) {
          setState(() {
            notifications = items;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            notifications = [];
          });
        }
      }
    }, onError: (e) {
      if (kDebugMode) print('Error in complaint listener: $e');
    });
    
    _subscriptions.add(subscription);

    // Also try alternative formats just in case
    final alternativeFormats = [
      'collection/student/$sid',  // Without leading slash
      '/student/$sid',             // Without "collection"
      'student/$sid',              // Without leading slash and "collection"
    ];

    for (var altPath in alternativeFormats) {
      final altSub = FirebaseFirestore.instance
          .collection('complaint')
          .where('reportBy', isEqualTo: altPath)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          if (kDebugMode) print('Found ${snapshot.docs.length} complaints with alternative path: $altPath');
          
          final List<_ComplaintNotification> items = [];
          for (var doc in snapshot.docs) {
            items.add(_mapDocToNotification(doc));
          }
          items.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
          
          if (mounted) {
            setState(() {
              notifications = items;
            });
          }
        }
      });
      _subscriptions.add(altSub);
    }
  }

  _ComplaintNotification _mapDocToNotification(DocumentSnapshot d) {
    final data = d.data() as Map<String, dynamic>? ?? {};
    
    // Extract fields based on your data structure
    final statusRaw = (data['reportStatus'] ?? data['status'] ?? data['ReportStatus'] ?? '').toString().trim().toLowerCase();
    final category = (data['damageCategory'] ?? data['damage_category'] ?? data['category'] ?? '').toString();
    final inventory = (data['inventoryDamage'] ?? data['inventory_damage'] ?? data['damageDesc'] ?? data['description'] ?? '').toString();
    final isRead = data['isRead'] ?? false;
    
    int? createdMs;
    final createdVal = data['createdAt'] ?? data['timestamp'] ?? data['created'];
    if (createdVal != null) {
      if (createdVal is int) {
        createdMs = createdVal;
      } else if (createdVal is double) {
        createdMs = createdVal.toInt();
      } else if (createdVal is String) {
        createdMs = int.tryParse(createdVal);
      } else if (createdVal is Timestamp) {
        createdMs = createdVal.millisecondsSinceEpoch;
      }
    }
    
    return _ComplaintNotification(
      id: d.id,
      status: statusRaw,
      category: category,
      inventory: inventory,
      createdAt: createdMs,
      isRead: isRead,
    );
  }

  Future<void> _markAsRead(String complaintId) async {
    try {
      await FirebaseFirestore.instance
          .collection('complaint')
          .doc(complaintId)
          .update({'isRead': true});
      
      if (kDebugMode) print('Marked complaint $complaintId as read');
    } catch (e) {
      if (kDebugMode) print('Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead({bool showSnackbar = true}) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (var notification in notifications) {
        if (!notification.isRead) {
          final docRef = FirebaseFirestore.instance
              .collection('complaint')
              .doc(notification.id);
          batch.update(docRef, {'isRead': true});
        }
      }
      
      await batch.commit();
      if (kDebugMode) print('Marked all complaints as read');
      
      if (mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error marking all as read: $e');
    }
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  Color _colorForStatus(String s) {
    if (s.contains('reject') || s == 'rejected') return Colors.red;
    if (s == 'assigned') return Colors.orange.shade700;
    if (s.contains('approve') || s == 'approved') return Colors.green;
    if (s == 'completed') return Colors.green.shade700;
    if (s == 'pending') return Colors.grey;
    return Colors.blueGrey;
  }

  IconData _iconForStatus(String s) {
    if (s.contains('reject') || s == 'rejected') return Icons.cancel;
    if (s == 'assigned') return Icons.engineering;
    if (s.contains('approve') || s == 'approved') return Icons.check_circle;
    if (s == 'completed') return Icons.done_all;
    if (s == 'pending') return Icons.hourglass_top;
    return Icons.info_outline;
  }

  Future<void> _manualRefresh() async {
    // Cancel existing subscriptions
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    
    // Re-setup listeners
    await _setupRealtimeListeners();
  }

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notification',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _manualRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _manualRefresh,
              child: notifications.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 6)],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Icons.notifications_none, size: 56, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text('No Reports Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                                    const SizedBox(height: 8),
                                    Text("You don't have any complaints yet.", style: TextStyle(color: Colors.grey[600])),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Live Updates Active',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Column(
                      children: [
                        // Live status banner
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Updates automatically • ${notifications.length} report${notifications.length != 1 ? 's' : ''}${unreadCount > 0 ? ' • $unreadCount unread' : ''}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Notification list
                        Expanded(
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final n = notifications[index];
                              final color = _colorForStatus(n.status);
                              final icon = _iconForStatus(n.status);
                              final title = n.category.isNotEmpty ? n.category : 'Report ${n.id}';
                              final subtitle = n.inventory.isNotEmpty ? n.inventory : 'No description';
                              return _NotificationCard(
                                icon: icon,
                                iconColor: Colors.white,
                                iconBgColor: color.withOpacity(0.12),
                                title: title,
                                subtitle: subtitle,
                                statusText: n.status.toUpperCase(),
                                showStatusDot: true,
                                statusColor: color,
                                isRead: n.isRead,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}

class _ComplaintNotification {
  final String id;
  final String status;
  final String category;
  final String inventory;
  final int? createdAt;
  final bool isRead;

  _ComplaintNotification({
    required this.id,
    required this.status,
    required this.category,
    required this.inventory,
    this.createdAt,
    this.isRead = false,
  });
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
  final Color? statusColor;
  final bool isRead;

  const _NotificationCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.time,
    this.statusText,
    this.showStatusDot = false,
    this.statusColor,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // MUCH MORE OBVIOUS DIFFERENCE:
        // Unread: Bright blue background
        // Read: Light gray background
        color: isRead ? Colors.grey.shade100 : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(12),
        border: isRead 
            ? Border.all(color: Colors.grey.shade300, width: 1)
            : Border.all(color: Colors.blue.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: isRead 
                ? Colors.grey.withOpacity(0.1) 
                : Colors.blue.withOpacity(0.3),
            spreadRadius: isRead ? 1 : 2,
            blurRadius: isRead ? 2 : 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // BIGGER, MORE OBVIOUS unread indicator
          if (!isRead)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

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
                Row(
                  children: [
                    // NEW label for unread
                    if (!isRead)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                          color: isRead ? Colors.grey.shade700 : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isRead ? Colors.grey.shade500 : Colors.grey.shade800,
                    fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    if (showStatusDot)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: statusColor ?? Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      statusText!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                        color: isRead ? Colors.grey.shade700 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}