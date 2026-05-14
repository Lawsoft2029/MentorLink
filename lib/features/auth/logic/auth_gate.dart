import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/welcome_screen.dart';
import 'package:mentorlinks_app_project/features/mentee/presentation/mentee_dashboard.dart';

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
        // If Firebase finds a valid user session, show the Dashboard
        if (snapshot.hasData) {
          return const MenteeDashboard();
        }

        // 3. Logic: No User Found
        // If no one is logged in, show the Welcome Screen
        return const WelcomeScreen();
      },
    );
  }
}