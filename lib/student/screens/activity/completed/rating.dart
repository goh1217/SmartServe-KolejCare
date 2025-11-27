import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rating Page',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const RatingPage(),
    );
  }
}

class RatingPage extends StatefulWidget {
  final String? complaintId;
  final String? technicianId;

  const RatingPage({super.key, this.complaintId, this.technicianId});

  @override
  _RatingPageState createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  double _rating = 3;
  final TextEditingController _feedbackController = TextEditingController();
  bool _loading = false;
  String? _ratingDocId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFE8E8E8),
        title: const Text(
          'Rating',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Picture and Name
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF5E4DB2),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: const AssetImage('assets/male.jpg'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Gregory Smith',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Rating Title and Star Rating
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'How was the repair?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Text(
              'Your feedback helps us improve maintenance.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Star Rating
            StarRating(
              rating: _rating,
              onRatingChanged: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
            const SizedBox(height: 24),
            // Feedback Input
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Tell us what went well or what still needs fixing...',
                style: TextStyle(fontSize: 14),
              ),
            ),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Your feedback...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),
            // Submit Button
            ElevatedButton(
              onPressed: _loading ? null : () => _submitFeedback(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E4DB2),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'Submit Feedback',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    if (widget.complaintId != null) {
      _loadExistingRating();
    }
  }

  Future<void> _loadExistingRating() async {
    setState(() => _loading = true);
    try {
      final q = await FirebaseFirestore.instance
          .collection('rating')
          .where('complaintID', isEqualTo: widget.complaintId)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final doc = q.docs.first;
        final data = doc.data();
        setState(() {
          _rating = (data['rating'] is num) ? (data['rating'] as num).toDouble() : _rating;
          _feedbackController.text = (data['comment'] ?? '').toString();
          _ratingDocId = doc.id;
        });
      }
    } catch (e) {
      // ignore errors, keep defaults
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitFeedback() async {
    final feedback = _feedbackController.text.trim();
    final rating = _rating;
    setState(() => _loading = true);
    try {
      final ratings = FirebaseFirestore.instance.collection('rating');
      final currentUser = FirebaseAuth.instance.currentUser;
      final studentId = currentUser?.uid ?? '';

      if (_ratingDocId != null) {
        await ratings.doc(_ratingDocId).update({
          'rating': rating,
          'comment': feedback,
          'date': FieldValue.serverTimestamp(),
          'studentID': studentId,
          'technicianID': widget.technicianId ?? '',
        });
      } else {
        await ratings.add({
          'complaintID': widget.complaintId ?? '',
          'rating': rating,
          'comment': feedback,
          'date': FieldValue.serverTimestamp(),
          'studentID': studentId,
          'technicianID': widget.technicianId ?? '',
        });
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Feedback Submitted'),
              content: Text('Rating: $rating\nFeedback: $feedback'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit feedback: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  final Function(double) onRatingChanged;

  const StarRating({
    super.key,
    required this.rating,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () {
            onRatingChanged(index + 1.0);
          },
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: const Color(0xFF5E4DB2),
            size: 32,
          ),
        );
      }),
    );
  }
}