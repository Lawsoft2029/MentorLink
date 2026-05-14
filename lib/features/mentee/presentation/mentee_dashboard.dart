import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'wallet_screen.dart';
import 'vault_screen.dart';
import 'live_session_screen.dart';

class MenteeDashboard extends StatefulWidget {
  const MenteeDashboard({super.key});

  @override
  State<MenteeDashboard> createState() => _MenteeDashboardState();
}

class _MenteeDashboardState extends State<MenteeDashboard> {
  int _selectedIndex = 0;

  // The pages used for the Bottom Navigation
  final List<Widget> _pages = [
    const HomeScreenContent(),
    const WalletScreen(),
    const VaultScreen(),
    const LiveSessionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // PROFESSIONAL FIX: Using IndexedStack ensures that when you are in a 
      // Live Session, switching to "Wallet" doesn't kill the video/code connection.
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF333697),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.storage), label: 'Vault'),
          BottomNavigationBarItem(icon: Icon(Icons.video_call), label: 'Live'),
        ],
      ),
    );
  }
}

class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MentorLinks Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF333697)),
            onPressed: () async {
              // This triggers the AuthGate to show the Welcome Screen
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCards(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Available Mentors",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // Placeholder for your Mentor List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFF333697), child: Icon(Icons.person, color: Colors.white)),
                  title: const Text("Expert Developer"),
                  subtitle: const Text("Flutter • Dart • Firebase"),
                  trailing: TextButton(
                    onPressed: () {
                      // Logic to start a session will go here
                    },
                    child: const Text("Connect"),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _statItem("Learning", "12 hrs", Colors.blue),
          const SizedBox(width: 10),
          _statItem("Wallet", "₦45,000", Colors.green),
        ],
      ),
    );
  }

  Widget _statItem(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}