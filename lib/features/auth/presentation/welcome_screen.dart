import 'package:flutter/material.dart';
import 'package:mentorlinks_app_project/features/mentor/presentaion/mentor_dashboard.dart';
import 'mentee_auth_screen.dart';
// FIXED: Linked relative package route pointing to the new features track

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
                  // ignore: deprecated_member_use
                  color: const Color(0xFF333697).withOpacity(0.1), // Updated for stable API compatibility
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.link, // Replace this icon with your Image.asset logo later
                  size: 60,
                  color: Color(0xFF333697),
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
              // MENTEE BUTTON
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

              // MENTOR BUTTON
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () {
                    // FIXED: Replaced placeholder alerts with direct push link to our Mentor Dashboard workspace
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MentorDashboard(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF333697), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "I want to Mentor",
                    style: TextStyle(fontSize: 18, color: Color(0xFF333697)),
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