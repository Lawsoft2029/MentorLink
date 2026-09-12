import 'package:cloud_firestore/cloud_firestore.dart';

class MatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches mentors matching a specific skill or track (e.g., "Flutter")
  Stream<QuerySnapshot<Map<String, dynamic>>> getMatchedMentors(
    String selectedSkill,
  ) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'mentor')
        .where('skills', arrayContains: selectedSkill)
        .snapshots();
  }

  /// Fetches all available mentors if no specific filter is applied
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllMentors() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'mentor')
        .snapshots();
  }
}
