import 'package:flutter/material.dart';
import 'mentor_auth_screen.dart'; // UPDATED: Import the authentication page
import 'mentee_auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. LOGO PLACEHOLDER
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  // FIXED: Swapped out deprecated withOpacity method call for modern withValues standard
                  color: const Color(0xFF333697).withValues(
                    alpha: 0.1,
                  ), // Updated for stable API compatibility
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.link,
                      size: 60,
                      color: Color(0xFF333697),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 2. WELCOME MESSAGE
              const Text(
                "MentorLinks",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333697),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 15),

              // 3. DESCRIPTION
              const Text(
                "Connecting expertise with curiosity. Get instant help, master new skills, and save lectures for offline learning.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 60),

              // 4. ROLE CHOICE BUTTONS
              // MENTEE BUTTON (Solid Indigo/Navy for Students)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MenteeAuthScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333697),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "I want to Learn (Mentee)",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // MENTOR BUTTON (Premium Deep Teal for Educators)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () {
                    // UPDATED: Corrected navigation routing to point to the mentor authentication checkpoint screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MentorAuthScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    // UPDATED: Shifted from blue to deep educational teal accent borders
                    side: const BorderSide(color: Color(0xFF00796B), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "I am a Mentor", // UPDATED: Clear onboarding copy adjustment
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF00796B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
              const Text(
                "Build. Learn. Earn.",
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
