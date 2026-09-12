import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/splash_screen.dart';
import 'package:mentorlinks_app_project/features/mentee/presentation/course_selection_screen.dart';
import 'package:mentorlinks_app_project/features/mentee/presentation/mentee_learning_hub_screen.dart';
import 'package:mentorlinks_app_project/features/mentor/presentation/mentor_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Connection State: Waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF333697)),
            ),
          );
        }

        // 2. User is Authenticated
        if (snapshot.hasData && snapshot.data != null) {
          final String uid = snapshot.data!.uid;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF333697)),
                  ),
                );
              }

              if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
                return const SplashScreen();
              }

              final userData =
                  userDocSnapshot.data!.data() as Map<String, dynamic>?;
              final String role =
                  userData?['role'] ?? userData?['accountType'] ?? 'mentee';

              if (role == 'mentor') {
                return const MentorDashboard();
              } else {
                // Mentee Flow Routing:
                // Check if user has enrolled courses
                final List enrolledCourses = userData?['enrolledCourses'] ?? [];

                if (enrolledCourses.isEmpty) {
                  // Step 2: New student needs to select course(s)
                  return const CourseSelectionScreen();
                } else {
                  // Step 7: Returning student sees their active Learning Hub
                  return const MenteeLearningHubScreen();
                }
              }
            },
          );
        }

        // 3. Unauthenticated -> Splash / Welcome
        return const SplashScreen();
      },
    );
  }
}
