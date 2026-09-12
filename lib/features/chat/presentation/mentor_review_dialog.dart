import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MentorReviewDialog extends StatefulWidget {
  final String mentorUid;
  final String sessionId;

  const MentorReviewDialog({
    super.key,
    required this.mentorUid,
    required this.sessionId,
  });

  @override
  State<MentorReviewDialog> createState() => _MentorReviewDialogState();
}

class _MentorReviewDialogState extends State<MentorReviewDialog> {
  double _selectedRating = 5.0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);

    try {
      final mentorRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.mentorUid);
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final mentorSnapshot = await transaction.get(mentorRef);

        if (!mentorSnapshot.exists) {
          throw Exception("Mentor profile not found.");
        }

        final data = mentorSnapshot.data()!;
        double currentAvgRating = (data['averageRating'] ?? 5.0).toDouble();
        int totalReviews = (data['totalReviewsCount'] ?? 0).toInt();

        // Calculate new running average rating
        double newAvgRating =
            ((currentAvgRating * totalReviews) + _selectedRating) /
            (totalReviews + 1);
        int newTotalReviews = totalReviews + 1;

        // Update mentor's aggregate ratings
        transaction.update(mentorRef, {
          'averageRating': newAvgRating,
          'totalReviewsCount': newTotalReviews,
        });

        // Mark session as reviewed
        transaction.update(sessionRef, {'isReviewed': true});
      });

      // Optionally save individual review to a subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.mentorUid)
          .collection('reviews')
          .add({
            'rating': _selectedRating,
            'feedback': _feedbackController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Thank you! Review submitted successfully."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error submitting review: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        "Rate Your Mentorship Session",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "How was your experience with your mentor? Your feedback helps maintain high standards across tech tracks.",
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.3),
            ),
            const SizedBox(height: 20),

            // Interactive Star Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                index += 1;
                return IconButton(
                  icon: Icon(
                    index <= _selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() => _selectedRating = index.toDouble());
                  },
                );
              }),
            ),
            const SizedBox(height: 16),

            // Feedback Text Field
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Write a short comment (optional)...",
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text("Skip", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isSubmitting ? null : _submitReview,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  "Submit Review",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
