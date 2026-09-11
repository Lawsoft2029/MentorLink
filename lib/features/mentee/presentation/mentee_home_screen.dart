// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:mentorlinks_app_project/features/profile/presentation/profile_dashboard_screen.dart';
import 'package:mentorlinks_app_project/features/chat/presentation/chat_screen.dart'; // <-- Added import for Chat
import 'vault_screen.dart';
import 'wallet_screen.dart';
import 'live_session_screen.dart';

class MenteeHomeScreen extends StatefulWidget {
  const MenteeHomeScreen({super.key});

  @override
  State<MenteeHomeScreen> createState() => _MenteeHomeScreenState();
}

class _MenteeHomeScreenState extends State<MenteeHomeScreen> {
  // Logic to switch between tabs
  int _currentIndex = 0;

  // The list of screens to display based on the bottom nav selection
  final List<Widget> _pages = [
    const HomeContent(), // Your original Home UI
    const VaultScreen(),
    const WalletScreen(),
    const ProfileDashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      // Displays the selected page from the list above
      body: _pages[_currentIndex],

      // 4. BOTTOM NAVIGATION BAR
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF333697),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, // Keeps labels visible
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: "Vault"),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: "Wallet"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),

      // The Emergency "Panic" Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to the Live Session / Timer screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LiveSessionScreen(sessionId: '', role: 'mentee')),
          );
        },
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.bolt, color: Colors.white),
        label: const Text(" Help me debug", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// We moved your original UI code into this "HomeContent" widget 
// so it can be swapped out by the BottomNavigationBar
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 1. CUSTOM HEADER
          Padding(
            padding: const EdgeInsets.all(25.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Hello, Learner!", style: TextStyle(color: Colors.grey)),
                    Text(
                      "Find your Mentor",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333697),
                      ),
                    ),
                  ],
                ),
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFF333697),
                  child: Icon(Icons.person, color: Colors.white),
                ),
              ],
            ),
          ),

          // 2. SEARCH & FILTER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search mentors...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. MENTOR LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              itemCount: 4,
              itemBuilder: (context, index) {
                return _buildMentorCard(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentorCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage('https://via.placeholder.com/150'),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  height: 15,
                  width: 15,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Engr. Samuel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text("Flutter & IoT Expert", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 5),
                Row(
                  children: const [
                    Icon(Icons.star, color: Colors.orange, size: 14),
                    Text(" 4.9 (120 reviews)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Text(
                "₦50/sec",
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333697)),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  print("Connecting to mentor...");
                  // Navigate to Chat Screen first so they can plan the session per our workflow!
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatScreen(
                        chatRoomId: "sample_mentor_mentee_room",
                        receiverName: "Engr. Samuel",
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF333697),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(60, 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Connect", style: TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}