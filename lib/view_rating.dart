import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String _extractIdRaw(String raw) {
  if (raw.isEmpty) return '';
  final parts = raw.split('/').where((s) => s.isNotEmpty).toList();
  return parts.isNotEmpty ? parts.last : raw;
}

Future<Map<String, dynamic>> _fetchPreviewData(
  String? complaintId,
  String? studentId,
) async {
  final Map<String, dynamic> out = {};

  if (complaintId != null && complaintId.isNotEmpty) {
    final cid = _extractIdRaw(complaintId);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(cid)
          .get();
      if (doc.exists)
        out['complaint'] = doc.data();
      else {
        final q = await FirebaseFirestore.instance
            .collection('complaint')
            .where('complaintID', isEqualTo: complaintId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) out['complaint'] = q.docs.first.data();
      }
    } catch (_) {}
  }

  if (studentId != null && studentId.isNotEmpty) {
    final sid = _extractIdRaw(studentId);
    try {
      final sdoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(sid)
          .get();
      if (sdoc.exists) out['student'] = sdoc.data();
    } catch (_) {}
  }

  return out;
}

class ViewRatingPage extends StatelessWidget {
  const ViewRatingPage({super.key});

  String _formatTimestamp(dynamic ts) {
    try {
      if (ts == null) return 'No date';
      DateTime dt;
      if (ts is Timestamp)
        dt = ts.toDate().toLocal();
      else if (ts is DateTime)
        dt = ts.toLocal();
      else
        dt =
            DateTime.tryParse(ts.toString())?.toLocal() ??
            DateTime.now().toLocal();
      return DateFormat('d MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return ts?.toString() ?? 'No date';
    }
  }

  Widget _buildStars(double rating) {
    final int full = rating.floor();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full)
          return const Icon(Icons.star, color: Color(0xFF5E4DB2), size: 18);
        return const Icon(
          Icons.star_border,
          color: Color(0xFF5E4DB2),
          size: 18,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ratings'),
        backgroundColor: const Color(0xFF6C28D9),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rating')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No ratings yet.'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final d = docs[index];
              final m = d.data() as Map<String, dynamic>? ?? {};
              final comment = (m['comment'] ?? '').toString();
              final ratingVal = (m['rating'] is num)
                  ? (m['rating'] as num).toDouble()
                  : 0.0;
              final complaintId = (m['complaintID'] ?? '').toString();
              final studentId = (m['studentID'] ?? '').toString();
              final technicianId = (m['technicianID'] ?? '').toString();
              final dateText = _formatTimestamp(m['date']);

              return FutureBuilder<Map<String, dynamic>>(
                future: _fetchPreviewData(
                  complaintId.isNotEmpty ? complaintId : null,
                  studentId.isNotEmpty ? studentId : null,
                ),
                builder: (context, previewSnap) {
                  final preview = previewSnap.data ?? {};
                  final complaintPreview =
                      preview['complaint'] as Map<String, dynamic>?;
                  final studentPreview =
                      preview['student'] as Map<String, dynamic>?;

                  final title =
                      (complaintPreview != null
                              ? (complaintPreview['inventoryDamageTitle'] ??
                                    complaintPreview['damageCategory'] ??
                                    complaintPreview['inventoryDamage'] ??
                                    complaintPreview['complaintID'])
                              : null)
                          ?.toString();

                  final studentName =
                      (studentPreview != null
                              ? (studentPreview['studentName'] ??
                                    studentPreview['name'])
                              : (complaintPreview != null
                                    ? (complaintPreview['reportByName'] ?? '')
                                    : ''))
                          ?.toString();

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RatingDetailPage(
                            complaintId: complaintId.isNotEmpty
                                ? complaintId
                                : null,
                            studentId: studentId.isNotEmpty ? studentId : null,
                            technicianId: technicianId.isNotEmpty
                                ? technicianId
                                : null,
                            rating: ratingVal,
                            comment: comment,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title != null && title.isNotEmpty
                                        ? title
                                        : (complaintId.isNotEmpty
                                              ? (complaintId)
                                              : d.id),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStars(ratingVal),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Student: ${(studentName?.isNotEmpty ?? false) ? studentName : (studentId.isNotEmpty ? studentId : 'N/A')}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (comment.isNotEmpty) Text(comment),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class RatingDetailPage extends StatelessWidget {
  final String? complaintId;
  final String? studentId;
  final String? technicianId;
  final double? rating;
  final String? comment;

  const RatingDetailPage({
    super.key,
    this.complaintId,
    this.studentId,
    this.technicianId,
    this.rating,
    this.comment,
  });

  String _formatTimestamp(dynamic ts) {
    try {
      if (ts == null) return 'No date';
      DateTime dt;
      if (ts is Timestamp)
        dt = ts.toDate().toLocal();
      else if (ts is DateTime)
        dt = ts.toLocal();
      else
        dt =
            DateTime.tryParse(ts.toString())?.toLocal() ??
            DateTime.now().toLocal();
      return DateFormat('d MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return ts?.toString() ?? 'No date';
    }
  }

  String _extractId(String raw) {
    if (raw.isEmpty) return '';
    final parts = raw.split('/').where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : raw;
  }

  Future<Map<String, dynamic>> _loadAll() async {
    final Map<String, dynamic> out = {};

    if (complaintId != null && complaintId!.isNotEmpty) {
      final cid = _extractId(complaintId!);
      final doc = await FirebaseFirestore.instance
          .collection('complaint')
          .doc(cid)
          .get();
      if (doc.exists)
        out['complaint'] = doc.data();
      else {
        // fallback: query by complaintID field
        final q = await FirebaseFirestore.instance
            .collection('complaint')
            .where('complaintID', isEqualTo: complaintId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) out['complaint'] = q.docs.first.data();
      }
    }

    if (studentId != null && studentId!.isNotEmpty) {
      final sid = _extractId(studentId!);
      final sdoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(sid)
          .get();
      if (sdoc.exists) out['student'] = sdoc.data();
    }

    if (technicianId != null && technicianId!.isNotEmpty) {
      final tid = _extractId(technicianId!);
      final tdoc = await FirebaseFirestore.instance
          .collection('technician')
          .doc(tid)
          .get();
      if (tdoc.exists) out['technician'] = tdoc.data();
    }

    return out;
  }

  Widget _buildStarsLocal(double rating) {
    final int full = rating.floor();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full)
          return const Icon(Icons.star, color: Color(0xFF5E4DB2), size: 18);
        return const Icon(
          Icons.star_border,
          color: Color(0xFF5E4DB2),
          size: 18,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rating Detail'),
        backgroundColor: const Color(0xFF6C28D9),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final data = snap.data ?? {};
          final complaint = data['complaint'] as Map<String, dynamic>?;
          final student = data['student'] as Map<String, dynamic>?;
          final technician = data['technician'] as Map<String, dynamic>?;

          // Date completed candidates
          dynamic completedTs;
          if (complaint != null) {
            completedTs =
                complaint['completedDate'] ??
                complaint['completedOn'] ??
                complaint['reviewedOn'] ??
                complaint['reportedDate'] ??
                complaint['reportedOn'];
          }

          // proof pictures: can be list or string
          List<String> proofPics = [];
          if (complaint != null) {
            final p =
                complaint['proofPic'] ??
                complaint['proofPics'] ??
                complaint['proof'] ??
                complaint['proofImage'];
            if (p is String && p.isNotEmpty)
              proofPics = [p];
            else if (p is List)
              proofPics = p
                  .map((e) => e?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toList();
          }

          final studentName = student != null
              ? (student['studentName'] ?? student['name'] ?? '').toString()
              : (complaint != null ? (complaint['reportByName'] ?? '') : '');
          final techName = technician != null
              ? (technician['technicianName'] ?? technician['name'] ?? '')
                    .toString()
              : (complaint != null ? (complaint['assignedToName'] ?? '') : '');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complaint ID: ${complaint != null ? (complaint['complaintID'] ?? '') : (complaintId ?? 'N/A')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Student: ${studentName.isNotEmpty ? studentName : (studentId ?? 'N/A')}',
                  style: const TextStyle(color: Color.fromARGB(255, 77, 75, 75)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Technician: ${techName.isNotEmpty ? techName : (technicianId ?? 'N/A')}',
                  style: const TextStyle(color: Color.fromARGB(255, 77, 75, 75)),
                ),
                const SizedBox(height: 12),
                // Rating summary
                Row(
                  children: [
                    _buildStarsLocal(rating ?? 0.0),
                    const SizedBox(width: 8),
                    Text(
                      '${(rating ?? 0.0).toStringAsFixed(0)}/5',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if ((comment ?? '').isNotEmpty)
                  Text('Comment: ${comment ?? ''}'),
                const SizedBox(height: 12),
                Text(
                  'Date completed: ${_formatTimestamp(completedTs)}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                // Complaint details
                const Text(
                  'Complaint Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Category: ${complaint != null ? (complaint['damageCategory'] ?? '') : ''}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Inventory: ${complaint != null ? (complaint['inventoryDamage'] ?? '') : ''}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Inventory Title: ${complaint != null ? (complaint['inventoryDamageTitle'] ?? '') : ''}',
                ),
                const SizedBox(height: 12),
                if (proofPics.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Proof images:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...proofPics.map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[200],
                                image: url.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(url),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'No proof images available',
                    style: TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: 12),
                if (complaint != null && complaint['description'] != null) ...[
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(complaint['description'].toString()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
