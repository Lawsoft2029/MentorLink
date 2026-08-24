import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SchedulingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Book a mentoring session
  Future<void> bookSession({
    required String mentorId,
    required String mentorName,
    required DateTime selectedDate,
    required TimeOfDay selectedTime,
    required String topic,
  }) async {
    final String menteeId = _auth.currentUser!.uid;
    final String menteeEmail = _auth.currentUser!.email ?? "mentee@mentorlinks.com";

    // Format time string
    final String timeString = "${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}";
    final String dateString = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    Map<String, dynamic> sessionData = {
      'mentorId': mentorId,
      'mentorName': mentorName,
      'menteeId': menteeId,
      'menteeEmail': menteeEmail,
      'date': dateString,
      'time': timeString,
      'topic': topic,
      'status': 'Scheduled',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('sessions').add(sessionData);
  }

  /// Stream of sessions for the logged-in user (mentee or mentor)
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserSessions() {
    final String currentUserId = _auth.currentUser!.uid;
    
    // Checks if user is either the mentee or the mentor in the session
    return _firestore
        .collection('sessions')
        .where('menteeId', isEqualTo: currentUserId)
        .snapshots();
  }

  /// Stream of upcoming sessions for the user
  Stream<QuerySnapshot<Map<String, dynamic>>> getUpcomingSessions() {
    final String currentUserId = _auth.currentUser!.uid;
    
    // We fetch sessions where the user is either the mentee or mentor and status is 'Scheduled'
    return _firestore
        .collection('sessions')
        .where('menteeId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'Scheduled')
        .snapshots();
  }
}