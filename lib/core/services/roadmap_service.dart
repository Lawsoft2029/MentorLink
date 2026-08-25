import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoadmapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetches roadmap milestones for the current mentee
  Stream<DocumentSnapshot<Map<String, dynamic>>> getMenteeRoadmap() {
    final String userId = _auth.currentUser!.uid;
    return _firestore.collection('roadmaps').doc(userId).snapshots();
  }

  /// Initialize dynamic roadmap based on user's selected profile interest
  Future<void> initializeDynamicRoadmap() async {
    final String userId = _auth.currentUser!.uid;
    final docRef = _firestore.collection('roadmaps').doc(userId);
    
    final doc = await docRef.get();
    if (!doc.exists) {
      // 1. Fetch user's profile to see their chosen track/interest
      final userDoc = await _firestore.collection('users').doc(userId).get();
      String selectedTrack = 'Cross-Platform Mobile Engineering';
      
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        // Look for common interest/track fields saved during onboarding
        selectedTrack = data['selectedTrack'] ?? data['interest'] ?? 'Cross-Platform Mobile Engineering';
      }

      // 2. Generate milestones dynamically based on the track
      List<Map<String, dynamic>> dynamicMilestones = _getMilestonesForTrack(selectedTrack);

      // 3. Save to Firestore
      await docRef.set({
        'trackName': selectedTrack,
        'milestones': dynamicMilestones,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Helper method to return custom milestones based on the selected skill track
  List<Map<String, dynamic>> _getMilestonesForTrack(String track) {
    String lowerTrack = track.toLowerCase();

    if (lowerTrack.contains('flutter') || lowerTrack.contains('mobile')) {
      return [
        {'title': 'Phase 1: Language Fundamentals & OOP', 'completed': false},
        {'title': 'Phase 2: UI Layouts & Navigation Systems', 'completed': false},
        {'title': 'Phase 3: State Management Architecture', 'completed': false},
        {'title': 'Phase 4: Backend Integration & Authentication', 'completed': false},
        {'title': 'Phase 5: Local Caching & Offline Persistence', 'completed': false},
        {'title': 'Phase 6: Production Build, CI/CD & Deployment', 'completed': false},
      ];
    } else if (lowerTrack.contains('backend') || lowerTrack.contains('cloud') || lowerTrack.contains('firebase')) {
      return [
        {'title': 'Phase 1: Database Architecture & Collections Design', 'completed': false},
        {'title': 'Phase 2: Serverless Functions & Business Logic', 'completed': false},
        {'title': 'Phase 3: Security Rules & Identity Management', 'completed': false},
        {'title': 'Phase 4: API Design & Performance Optimization', 'completed': false},
        {'title': 'Phase 5: Monitoring, Analytics & Automated Backup', 'completed': false},
      ];
    } else {
      // General Professional Software Engineering Track
      return [
        {'title': 'Phase 1: Core Problem Solving & Logic', 'completed': false},
        {'title': 'Phase 2: Version Control & Collaborative Workflows', 'completed': false},
        {'title': 'Phase 3: Software Design Patterns & Best Practices', 'completed': false},
        {'title': 'Phase 4: Testing, Debugging & QA Protocols', 'completed': false},
        {'title': 'Phase 5: Final Capstone Project & Deployment', 'completed': false},
      ];
    }
  }

  /// Toggle milestone completion status
  Future<void> toggleMilestone(List milestones, int index) async {
    final String userId = _auth.currentUser!.uid;
    milestones[index]['completed'] = !milestones[index]['completed'];

    await _firestore.collection('roadmaps').doc(userId).update({
      'milestones': milestones,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}