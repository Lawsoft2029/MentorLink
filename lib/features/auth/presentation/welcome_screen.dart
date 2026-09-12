import 'package:flutter/material.dart';
import 'mentor_auth_screen.dart'; // UPDATED: Import the authentication page
import 'mentee_auth_screen.dart';
import 'enterprise_register_screen.dart'; // IMPORTED THE ENTERPRISE REGISTER SCREEN

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
              // 4. ROLE CHOICE BUTTONS (Side-by-Side Compact Layout)
              Row(
                children: [
                  // MENTEE BUTTON
                  Expanded(
                    child: SizedBox(
                      height: 55,
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Find a Mentor",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),

                  // MENTOR BUTTON
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MentorAuthScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF00796B),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Become a Mentor",
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF00796B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
              const Text(
                "Build. Learn. Earn.",
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),

              // --- DISCREET ENTERPRISE FOOTER LINK ---
              const SizedBox(height: 15),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EnterpriseRegisterScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Are you a company or bootcamp? Explore Enterprise",
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
