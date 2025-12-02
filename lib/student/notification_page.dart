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
  // Track the last known status per complaint to detect changes
  final Map<String, String> _lastKnownStatus = {};
  
  // Stream subscriptions for real-time updates
  final List<StreamSubscription> _subscriptions = [];
  String? _studentDocId;
  String? _currentUid;
  
  // Track if we've already marked as read on this session
  bool _hasMarkedAsRead = false;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    // Mark all as read after delay
    _markAllAsReadOnEnter();
  }

  Future<void> _markAllAsReadOnEnter() async {
    // Wait 3 seconds so user can see unread notifications first
    await Future.delayed(const Duration(seconds: 3));
    if (mounted && notifications.isNotEmpty && !_hasMarkedAsRead) {
      await _markAllAsRead(showSnackbar: false);
      _hasMarkedAsRead = true;
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

      if (kDebugMode) print('🔍 Current auth UID: $uid');

      // Find student doc id using UID from student collection
      final studentQuery = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
      
      if (kDebugMode) {
        print('📋 Student query results: ${studentQuery.docs.length} docs');
      }
          
      if (studentQuery.docs.isNotEmpty) {
        _studentDocId = studentQuery.docs.first.id;
        if (kDebugMode) {
          final data = studentQuery.docs.first.data();
          print('✓ Found student document:');
          print('  Doc ID: $_studentDocId');
          print('  authUid: ${data['authUid']}');
          print('  email: ${data['email']}');
          print('  studentName: ${data['studentName']}');
        }
      } else {
        if (kDebugMode) print('⚠️ No student found by authUid, trying email...');
        final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        if (userEmail.isNotEmpty) {
          final byEmail = await FirebaseFirestore.instance
              .collection('student')
              .where('email', isEqualTo: userEmail)
              .limit(1)
              .get();
          if (byEmail.docs.isNotEmpty) {
            _studentDocId = byEmail.docs.first.id;
            if (kDebugMode) {
              print('✓ Found student by email: $_studentDocId');
            }
          } else {
            if (kDebugMode) print('❌ No student found by email either!');
          }
        }
      }

      if (_studentDocId != null && _studentDocId!.isNotEmpty) {
        _listenToComplaints();
      } else {
        if (kDebugMode) print('❌ Could not find student document!');
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

    if (kDebugMode) {
      print('\n=== SETUP LISTENER ===');
      print('Student Doc ID: $sid');
      print('Current UID: $_currentUid');
      print('Looking for reportBy: /collection/student/$sid');
      print('========================\n');
    }

    // REMOVED orderBy to avoid index issues - we'll sort client-side
    final subscription = FirebaseFirestore.instance
        .collection('complaint')
        .limit(500)
        .snapshots()
        .listen((snapshot) {
      if (kDebugMode) {
        print('\n=== Broad Real-time Update Received ===');
        print('Total complaints in snapshot: ${snapshot.docs.length}');
      }
      
      // DEBUG: Print first 10 complaints to see their structure
      if (kDebugMode && snapshot.docs.isNotEmpty) {
        print('\n=== DEBUGGING ALL COMPLAINTS ===');
        for (var i = 0; i < (snapshot.docs.length > 10 ? 10 : snapshot.docs.length); i++) {
          final doc = snapshot.docs[i];
          final data = doc.data();
          print('\nComplaint ${i+1} (${doc.id}):');
          print('  reportBy: ${data['reportBy']}');
          print('  reportedBy: ${data['reportedBy']}');
          print('  reportBy type: ${data['reportBy']?.runtimeType ?? 'null'}');
          if (data['reportBy'] is DocumentReference) {
            print('  reportBy path: ${(data['reportBy'] as DocumentReference).path}');
          }
          print('  status: ${data['reportStatus'] ?? data['status'] ?? 'no status'}');
          print('  category: ${data['damageCategory'] ?? 'no category'}');
          print('  isArchived: ${data['isArchived']}');
          print('  createdAt: ${data['createdAt']}');
        }
        print('=== END DEBUG ===\n');
      }

      final List<_ComplaintNotification> items = [];
      final Set<String> changedIds = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        // skip archived
        if (data['isArchived'] == true) continue;

        // determine whether this doc belongs to the current student
        final rb = data['reportBy'] ?? data['reportedBy'];
        bool matches = false;

        try {
          if (rb == null) {
            matches = false;
            if (kDebugMode) print('  Complaint ${doc.id}: reportBy is NULL');
          } else if (rb is DocumentReference) {
            final path = rb.path;
            if (kDebugMode) print('  Complaint ${doc.id}: DocumentReference path = $path');
            if (path.contains(sid)) {
              matches = true;
              if (kDebugMode) print('    ✓ MATCH: path contains $sid');
            }
          } else {
            final s = rb.toString();
            if (kDebugMode) print('  Complaint ${doc.id}: String reportBy = "$s"');
            if (s.contains(sid) || s == sid) {
              matches = true;
              if (kDebugMode) print('    ✓ MATCH: string contains $sid');
            }
            if (!matches && (s == '/collection/student' || s == 'collection/student' || s == 'student/$sid')) {
              final uid = _currentUid;
              final repId = data['reportedById'];
              final repEmail = data['reportedByEmail'] ?? data['reporterEmail'] ?? data['email'];
              final createdBy = data['createdBy'] ?? data['authUid'] ?? data['creatorUid'];
              if (repId == sid || repId == uid) matches = true;
              if (!matches && uid != null && (createdBy == uid)) matches = true;
              if (!matches && repEmail != null) {
                final myEmail = FirebaseAuth.instance.currentUser?.email;
                if (myEmail != null && repEmail.toString().toLowerCase() == myEmail.toLowerCase()) matches = true;
              }
              if (!matches) {
                final createdVal = data['createdAt'] ?? data['timestamp'] ?? data['reportedDate'];
                if (createdVal is Timestamp) {
                  final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(createdVal.millisecondsSinceEpoch));
                  if (age.inDays <= 14) {
                    if (kDebugMode) print('Fallback recent doc accepted ${doc.id} age ${age.inDays}d');
                    matches = true;
                  }
                }
              }
            }
          }

          final uid = _currentUid;
          if (!matches && uid != null) {
            if (rb == uid) matches = true;
            else if (rb is String && rb.contains(uid)) matches = true;
          }
        } catch (e) {
          if (kDebugMode) print('Error matching reportBy for ${doc.id}: $e');
        }

        if (!matches) continue;

        if (kDebugMode) {
          print('✓ MATCHED complaint ${doc.id} for student $sid');
        }

        // CRITICAL: Detect status changes
        try {
          final statusRaw = (data['reportStatus'] ?? data['status'] ?? data['ReportStatus'] ?? '').toString().trim().toLowerCase();
          final previous = _lastKnownStatus[doc.id];
          
          if (previous == null) {
            // First time seeing this complaint
            _lastKnownStatus[doc.id] = statusRaw;
          } else if (previous != statusRaw && statusRaw.isNotEmpty) {
            // STATUS CHANGED! Mark as unread
            if (kDebugMode) {
              print('🔔 STATUS CHANGE DETECTED for ${doc.id}');
              print('   Previous: $previous → New: $statusRaw');
            }
            
            _lastKnownStatus[doc.id] = statusRaw;
            changedIds.add(doc.id);
            
            // Mark unread in Firestore
            FirebaseFirestore.instance.collection('complaint').doc(doc.id).update({
              'isRead': false,
              'lastStatusChangedAt': FieldValue.serverTimestamp(),
            }).then((_) {
              if (kDebugMode) print('✓ Marked ${doc.id} as unread in Firestore');
            }).catchError((e) {
              if (kDebugMode) print('❌ Failed to mark as unread for ${doc.id}: $e');
            });
          }
        } catch (e) {
          if (kDebugMode) print('Error detecting status change for ${doc.id}: $e');
        }

        items.add(_mapDocToNotification(doc));
      }

      // IMPORTANT: Update isRead locally for newly changed items
      // This ensures they show as unread immediately before Firestore updates
      if (changedIds.isNotEmpty) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        for (var i = 0; i < items.length; i++) {
          if (changedIds.contains(items[i].id)) {
            items[i] = _ComplaintNotification(
              id: items[i].id,
              status: items[i].status,
              category: items[i].category,
              inventory: items[i].inventory,
              createdAt: items[i].createdAt,
              isRead: false, // Force unread
              lastChangedAt: nowMs, // Mark when it changed
            );
          }
        }
      }

      // IMPROVED SORT: 
      // 1. Unread first (isRead = false)
      // 2. Within unread, sort by lastChangedAt (newest changes first)
      // 3. Then by createdAt (newest first)
      items.sort((a, b) {
        // Primary sort: unread before read
        if (a.isRead != b.isRead) {
          return a.isRead ? 1 : -1; // false (unread) comes first
        }
        
        // Secondary sort: newest status change first
        final aChanged = a.lastChangedAt ?? a.createdAt ?? 0;
        final bChanged = b.lastChangedAt ?? b.createdAt ?? 0;
        return bChanged.compareTo(aChanged); // Descending (newest first)
      });

      if (kDebugMode) {
        print('📊 Notification list updated:');
        print('   Total: ${items.length}');
        print('   Unread: ${items.where((n) => !n.isRead).length}');
        if (changedIds.isNotEmpty) {
          print('   🔄 Recently changed: ${changedIds.length}');
        }
      }

      if (mounted) setState(() => notifications = items);
    }, onError: (e) {
      if (kDebugMode) print('Broad listener error: $e');
    });

    _subscriptions.add(subscription);
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
    
    int? lastChangedMs;
    final lastChangedVal = data['lastStatusChangedAt'];
    if (lastChangedVal is Timestamp) {
      lastChangedMs = lastChangedVal.millisecondsSinceEpoch;
    } else if (lastChangedVal is int) {
      lastChangedMs = lastChangedVal;
    } else if (lastChangedVal is double) {
      lastChangedMs = lastChangedVal.toInt();
    } else if (lastChangedVal is String) {
      lastChangedMs = int.tryParse(lastChangedVal);
    }
    
    return _ComplaintNotification(
      id: d.id,
      status: statusRaw,
      category: category,
      inventory: inventory,
      createdAt: createdMs,
      isRead: isRead,
      lastChangedAt: lastChangedMs,
    );
  }

  Future<void> _markAllAsRead({bool showSnackbar = true}) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      int count = 0;
      
      for (var notification in notifications) {
        if (!notification.isRead) {
          final docRef = FirebaseFirestore.instance
              .collection('complaint')
              .doc(notification.id);
          batch.update(docRef, {'isRead': true});
          count++;
        }
      }
      
      if (count > 0) {
        await batch.commit();
        if (kDebugMode) print('✓ Marked $count complaints as read');
        
        if (mounted && showSnackbar) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Marked $count notification${count != 1 ? 's' : ''} as read'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error marking all as read: $e');
    }
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  Color _colorForStatus(String s) {
    if (s.contains('reject') || s == 'rejected') return Colors.red;
    if (s == 'ongoing') return Colors.orange.shade700;
    if (s.contains('approve') || s == 'approved') return Colors.green;
    if (s == 'completed') return Colors.green.shade700;
    if (s == 'pending') return Colors.grey;
    return Colors.blueGrey;
  }

  IconData _iconForStatus(String s) {
    if (s.contains('reject') || s == 'rejected') return Icons.cancel;
    if (s == 'ongoing') return Icons.engineering;
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
    
    // Reset marked flag
    _hasMarkedAsRead = false;
    
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
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.blue),
              onPressed: () => _markAllAsRead(showSnackbar: true),
              tooltip: 'Mark all as read',
            ),
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
  final int? lastChangedAt;

  _ComplaintNotification({
    required this.id,
    required this.status,
    required this.category,
    required this.inventory,
    this.createdAt,
    this.isRead = false,
    this.lastChangedAt,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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