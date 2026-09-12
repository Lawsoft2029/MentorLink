import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mentorlinks_app_project/features/chat/presentation/chat_screen.dart';
import 'package:mentorlinks_app_project/features/classroom/presentation/virtual_classroom_screen.dart';
import 'package:mentorlinks_app_project/features/enterprise/presentation/enterprise_registration_screen.dart';
import 'package:mentorlinks_app_project/features/mentee/presentation/mentor_matching_screen.dart';
import 'package:mentorlinks_app_project/features/mentee/presentation/skill_roadmap_screen.dart';
import 'package:mentorlinks_app_project/features/profile/presentation/profile_dashboard_screen.dart';
import 'package:mentorlinks_app_project/features/review/presentation/rate_mentor_dialog.dart';
import 'package:mentorlinks_app_project/features/scheduling/presentation/book_session_screen.dart';

class MainDashboardScreen extends StatelessWidget {
  const MainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("MentorLinks Hub"),
        backgroundColor: const Color(0xFF333697),
        foregroundColor: Colors.white,
        actions: [
          // Profile Button
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileDashboardScreen(),
                ),
              );
            },
          ),
          // Logout / Exit Button added here to prevent getting stuck
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // Pops all routes and returns to root/auth screen (adjust route name if needed)
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF333697).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFF333697).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome back,",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? "Engineering Scholar",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333697),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333697),
              ),
            ),
            const SizedBox(height: 12),

            // Action Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  // 1. Mentor Matchmaking
                  _DashboardCard(
                    icon: Icons.person_search,
                    title: "Find Mentors",
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MentorMatchingScreen(
                            menteeSkillInterest: "Flutter",
                          ),
                        ),
                      );
                    },
                  ),

                  // 2. Real-Time Chat (Example Chat Room)
                  _DashboardCard(
                    icon: Icons.chat_bubble_outline,
                    title: "Live Chat",
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatScreen(
                            chatRoomId: "sample_room_123",
                            receiverName: "Expert Mentor",
                          ),
                        ),
                      );
                    },
                  ),

                  // 3. Book a Session
                  _DashboardCard(
                    icon: Icons.calendar_month,
                    title: "Book Session",
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BookSessionScreen(
                            mentorId: "sample_mentor_id",
                            mentorName: "Expert Mentor",
                          ),
                        ),
                      );
                    },
                  ),

                  // 4. Rate a Mentor Dialog
                  _DashboardCard(
                    icon: Icons.star_rate,
                    title: "Rate Session",
                    color: Colors.amber.shade800,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => const RateMentorDialog(
                          mentorId: "sample_mentor_id",
                          mentorName: "Expert Mentor",
                        ),
                      );
                    },
                  ),

                  // 5. Skill Roadmap Card
                  _DashboardCard(
                    icon: Icons.map,
                    title: "My Roadmap",
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SkillRoadmapScreen(),
                        ),
                      );
                    },
                  ),

                  // 6. Virtual Classroom Card
                  _DashboardCard(
                    icon: Icons.video_call,
                    title: "Live Class",
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VirtualClassroomScreen(
                            roomName: "Flutter Mastery Room",
                            participantName: "Expert Mentor",
                            sessionId: "demo_session_001",
                            role: "mentee",
                          ),
                        ),
                      );
                    },
                  ),

                  // 7. Enterprise Onboarding & Verification Card
                  _DashboardCard(
                    icon: Icons.business,
                    title: "Enterprise B2B",
                    color: Colors.teal.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const EnterpriseRegistrationScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
