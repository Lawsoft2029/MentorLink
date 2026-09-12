import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EarningsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream completed sessions for the logged-in mentor
  Stream<QuerySnapshot<Map<String, dynamic>>> getMentorCompletedSessions() {
    final String mentorId = _auth.currentUser!.uid;

    return _firestore
        .collection('sessions')
        .where('mentorId', isEqualTo: mentorId)
        .where('status', isEqualTo: 'Completed')
        .snapshots();
  }

  /// Submit a payout request to Flutterwave / Admin queue
  Future<void> requestPayout({
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final String mentorId = _auth.currentUser!.uid;
    final String email = _auth.currentUser!.email ?? "mentor@mentorlinks.com";

    await _firestore.collection('payout_requests').add({
      'mentorId': mentorId,
      'mentorEmail': email,
      'amount': amount,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'status': 'Pending Approval',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }
}
