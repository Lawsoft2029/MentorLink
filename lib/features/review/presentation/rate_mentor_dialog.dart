import 'package:flutter/material.dart';
import '../../../core/services/review_service.dart';

class RateMentorDialog extends StatefulWidget {
  final String mentorId;
  final String mentorName;

  const RateMentorDialog({
    super.key,
    required this.mentorId,
    required this.mentorName,
  });

  @override
  State<RateMentorDialog> createState() => _RateMentorDialogState();
}

class _RateMentorDialogState extends State<RateMentorDialog> {
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _commentController = TextEditingController();
  double _currentRating = 5.0;
  bool _isLoading = false;

  void _submit() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _reviewService.submitReview(
        mentorId: widget.mentorId,
        rating: _currentRating,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Thank you! Review submitted successfully."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error submitting review: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Rate ${widget.mentorName}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("How was your mentorship session?"),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () =>
                      setState(() => _currentRating = (index + 1).toDouble()),
                  icon: Icon(
                    index < _currentRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: "Write your feedback...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF333697),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text("Submit", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
