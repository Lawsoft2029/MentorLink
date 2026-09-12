import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/interests_screen.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/welcome_screen.dart';

class AuthService extends StatelessWidget {
  const AuthService({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the user is logged in, send them to Course Selection
        if (snapshot.hasData) {
          return const CourseSelectionScreen();
        }
        // Otherwise, show the Welcome/Auth screen
        return const WelcomeScreen();
      },
    );
  }
}
