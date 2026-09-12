import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit a review and rating for a mentor
  Future<void> submitReview({
    required String mentorId,
    required double rating,
    required String comment,
  }) async {
    final String menteeId = _auth.currentUser!.uid;
    final String menteeEmail =
        _auth.currentUser!.email ?? "mentee@mentorlinks.com";

    // Save the review document
    await _firestore.collection('reviews').add({
      'mentorId': mentorId,
      'menteeId': menteeId,
      'menteeEmail': menteeEmail,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Optionally update the mentor's aggregate rating in their user document
    // (In a full app, you can calculate average rating, but here we record the feedback)
  }

  /// Stream reviews for a specific mentor
  Stream<QuerySnapshot<Map<String, dynamic>>> getMentorReviews(
    String mentorId,
  ) {
    return _firestore
        .collection('reviews')
        .where('mentorId', isEqualTo: mentorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
