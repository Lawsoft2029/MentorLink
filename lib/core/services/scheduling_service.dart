import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SchedulingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a recurring course schedule created by the Mentor after discussion
  Future<String> createMentorSchedule({
    required String mentorId,
    required String mentorName,
    required String menteeId,
    required String menteeName,
    required String menteeEmail,
    required String courseTitle,
    required List<String> daysOfWeek,
    required String timeOfDayString,
    required int frequencyPerWeek,
    required int totalSessions,
    required DateTime startDate,
    String? additionalNotes,
  }) async {
    final String formattedDate =
        "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";

    // 1. Create top-level schedule document
    final scheduleRef = await _firestore.collection('schedules').add({
      'mentorId': mentorId,
      'mentorName': mentorName,
      'menteeId': menteeId,
      'menteeName': menteeName,
      'menteeEmail': menteeEmail,
      'courseTitle': courseTitle,
      'daysOfWeek': daysOfWeek,
      'time': timeOfDayString,
      'frequencyPerWeek': frequencyPerWeek,
      'totalSessions': totalSessions,
      'completedSessions': 0,
      'startDate': formattedDate,
      'additionalNotes': additionalNotes ?? '',
      'status': 'Active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Add immediate upcoming session entry in 'sessions' for live readiness tracking
    await _firestore.collection('sessions').add({
      'scheduleId': scheduleRef.id,
      'mentorId': mentorId,
      'mentorName': mentorName,
      'menteeId': menteeId,
      'menteeName': menteeName,
      'menteeEmail': menteeEmail,
      'courseTitle': courseTitle,
      'topic': "$courseTitle with $mentorName ($frequencyPerWeek times/week)",
      'days': daysOfWeek.join(', '),
      'date': formattedDate,
      'time': timeOfDayString,
      'status': 'Scheduled',
      'totalSessions': totalSessions,
      'sessionNumber': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Create reminder notifications for both Mentee and Mentor
    await _createClassReminder(
      recipientId: menteeId,
      recipientRole: 'mentee',
      courseTitle: courseTitle,
      counterpartName: mentorName,
      timeString: timeOfDayString,
      daysString: daysOfWeek.join(', '),
    );

    await _createClassReminder(
      recipientId: mentorId,
      recipientRole: 'mentor',
      courseTitle: courseTitle,
      counterpartName: menteeName,
      timeString: timeOfDayString,
      daysString: daysOfWeek.join(', '),
    );

    return scheduleRef.id;
  }

  /// Helper to record in-app reminder in Firestore
  Future<void> _createClassReminder({
    required String recipientId,
    required String recipientRole,
    required String courseTitle,
    required String counterpartName,
    required String timeString,
    required String daysString,
  }) async {
    await _firestore.collection('reminders').add({
      'recipientId': recipientId,
      'recipientRole': recipientRole,
      'courseTitle': courseTitle,
      'counterpartName': counterpartName,
      'time': timeString,
      'days': daysString,
      'isRead': false,
      'title': "Upcoming Class: $courseTitle",
      'message':
          "You have class with $counterpartName on $daysString at $timeString.",
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Book a one-off mentoring session (Mentee initiated)
  Future<void> bookSession({
    required String mentorId,
    required String mentorName,
    required DateTime selectedDate,
    required TimeOfDay selectedTime,
    required String topic,
  }) async {
    final String menteeId = _auth.currentUser!.uid;
    final String menteeEmail =
        _auth.currentUser!.email ?? "mentee@mentorlinks.com";

    final String timeString =
        "${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}";
    final String dateString =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    Map<String, dynamic> sessionData = {
      'mentorId': mentorId,
      'mentorName': mentorName,
      'menteeId': menteeId,
      'menteeEmail': menteeEmail,
      'courseTitle': topic,
      'date': dateString,
      'time': timeString,
      'topic': topic,
      'status': 'Scheduled',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('sessions').add(sessionData);
  }

  /// Mark session as Live / Ready to notify mentor and mentee
  Future<void> triggerStartClass({
    required String sessionId,
    required String initiatedByRole,
  }) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': 'live',
      'liveReady': true,
      'hostRole': initiatedByRole,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of upcoming sessions for a specific mentee
  Stream<QuerySnapshot<Map<String, dynamic>>> getMenteeUpcomingClasses(
    String menteeId,
  ) {
    return _firestore
        .collection('sessions')
        .where('menteeId', isEqualTo: menteeId)
        .snapshots();
  }

  /// Stream of upcoming sessions for a specific mentor
  Stream<QuerySnapshot<Map<String, dynamic>>> getMentorUpcomingClasses(
    String mentorId,
  ) {
    return _firestore
        .collection('sessions')
        .where('mentorId', isEqualTo: mentorId)
        .snapshots();
  }

  /// Stream of sessions for the logged-in user (mentee or mentor)
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserSessions() {
    final String currentUserId = _auth.currentUser?.uid ?? '';
    return _firestore
        .collection('sessions')
        .where('menteeId', isEqualTo: currentUserId)
        .snapshots();
  }

  /// Stream of upcoming sessions for the user
  Stream<QuerySnapshot<Map<String, dynamic>>> getUpcomingSessions() {
    final String currentUserId = _auth.currentUser?.uid ?? '';
    return _firestore
        .collection('sessions')
        .where('menteeId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'Scheduled')
        .snapshots();
  }

  /// Stream active schedules for a mentee
  Stream<QuerySnapshot<Map<String, dynamic>>> getMenteeSchedules(
    String menteeId,
  ) {
    return _firestore
        .collection('schedules')
        .where('menteeId', isEqualTo: menteeId)
        .snapshots();
  }
}
