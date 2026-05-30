import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // REQUIRED: For reading role profile records
import 'package:mentorlinks_app_project/features/auth/presentation/welcome_screen.dart';
import 'package:mentorlinks_app_project/features/mentee/presentation/mentee_dashboard.dart';
import 'package:mentorlinks_app_project/features/mentor/presentation/mentor_dashboard.dart'; // REQUIRED: For routing mentors correctly

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // This listener connects directly to Firebase
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        // 1. Connection State: Waiting
        // This is shown while Firebase is checking the local cache/server
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF333697),
              ),
            ),
          );
        }

        // 2. Logic: User is Authenticated
        // If Firebase finds a valid user session, evaluate their profile role type
        if (snapshot.hasData) {
          final String uid = snapshot.data!.uid;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF333697),
                    ),
                  ),
                );
              }

              // Safety check: If document doesn't exist yet, send back to welcome
              if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
                return const WelcomeScreen();
              }

              final userData = userDocSnapshot.data!.data() as Map<String, dynamic>?;
              final String accountType = userData?['accountType'] ?? 'mentee';

              if (accountType == 'mentor') {
                return const MentorDashboard();
              } else {
                return const MenteeDashboard();
              }
            },
          );
        }

        // 3. Logic: No User Found
        // If no one is logged in, show the Welcome Screen
        return const WelcomeScreen();
      },
    );
  }
}