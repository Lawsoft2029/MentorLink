import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/interests_screen.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/welcome_screen.dart';
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading spinner while checking the login status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF333697))),
          );
        }

        // If the user is logged in, show the Course Selection (Interests) Screen
        if (snapshot.hasData) {
          return const CourseSelectionScreen();
        }

        // Otherwise, show the Welcome Screen
        return const WelcomeScreen();
      },
    );
  }
}