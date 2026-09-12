import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> submitMentorRating({
  required String mentorUid,
  required double newRatingValue,
}) async {
  final mentorRef = FirebaseFirestore.instance
      .collection('users')
      .doc(mentorUid);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(mentorRef);
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>;

    // Grab existing values or default to 0
    double currentAverage = (data['averageRating'] ?? 0.0).toDouble();
    int currentCount = (data['totalReviewsCount'] ?? 0).toInt();

    // Calculate new running average: ((CurrentAvg * CurrentCount) + NewRating) / (CurrentCount + 1)
    int newCount = currentCount + 1;
    double newAverage =
        ((currentAverage * currentCount) + newRatingValue) / newCount;

    // Update Firestore atomically
    transaction.update(mentorRef, {
      'averageRating': double.parse(
        newAverage.toStringAsFixed(1),
      ), // Keep 1 decimal place
      'totalReviewsCount': newCount,
    });
  });
}
