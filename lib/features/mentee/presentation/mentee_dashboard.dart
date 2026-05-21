import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added to stream user wallet updates
import 'package:mentorlinks_app_project/features/auth/presentation/welcome_screen.dart';
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

  // Function to simulate earning money by watching an ad
  Future<void> _watchAdAndEarn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      // Increment the balance field by 0.05 dollars
      await userDoc.update({
        'walletBalanceUSD': FieldValue.increment(0.05),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentee Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF333697)),
            onPressed: () async {
              // 1. Logs the user out of the active global session state
              await FirebaseAuth.instance.signOut();
              
              // 2. FIXED: Explicitly drops user to WelcomeScreen and purges prior routing views
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      // Wrapped in a StreamBuilder to make your variables listen natively to Firebase changes
      body: StreamBuilder<DocumentSnapshot>(
        stream: uid != null 
            ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
            : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Fallbacks if data doesn't exist yet or loading fails
          double walletBalanceUSD = 0.00;
          String userTier = 'Freemium';
          String learningHours = "12 hrs"; 

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            walletBalanceUSD = (data['walletBalanceUSD'] ?? 0.0).toDouble();
            userTier = data['userTier'] ?? 'Freemium';
            
            // Map totalMinutesLearned tracking to a display string if it exists
            if (data['totalMinutesLearned'] != null) {
              int mins = data['totalMinutesLearned'];
              learningHours = mins >= 60 ? "${(mins / 60).toStringAsFixed(1)} hrs" : "$mins mins";
            }
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display the stat items dynamically based on Firestore calculations
                _buildStatCards(learningHours, walletBalanceUSD),
                
                // --- IN-APP FREEMIUM MONETIZATION SIMULATOR BANNER ---
                if (userTier == 'Freemium')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.greenAccent, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt, color: Colors.greenAccent),
                              const SizedBox(width: 8),
                              Text(
                                "Freemium Plan Active",
                                style: TextStyle(color: Colors.green[300], fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Watch short ads to load tokens into your operational wallet instantly.",
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _watchAdAndEarn,
                              icon: const Icon(Icons.play_circle_filled, color: Colors.white),
                              label: const Text("Simulate Ad (Earn \$0.05)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF333697),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                // Padding framework for section header
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
                    // Simulating a standard operational connection rate ($0.10/min)
                    const double mentorRatePerMin = 0.10;

                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFF333697), child: Icon(Icons.person, color: Colors.white)),
                      title: const Text("Expert Developer"),
                      subtitle: const Text("Flutter • Dart • Firebase\nRate: \$0.10/min"),
                      trailing: TextButton(
                        onPressed: () async {
                          // 1. Operational Verification: Validate baseline balance allocation
                          if (walletBalanceUSD >= mentorRatePerMin) {
                            if (uid != null) {
                              // 2. State Deduction: Debit baseline token for 1 connection unit
                              final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
                              await userDoc.update({
                                'walletBalanceUSD': FieldValue.increment(-mentorRatePerMin),
                              });
                            }

                            // 3. Interface Routing: Access parent state to swap IndexedStack to Live (index 3)
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Deducting credit... Routing to Live Session room.")),
                              );

                              final parentState = context.findAncestorStateOfType<_MenteeDashboardState>();
                              if (parentState != null) {
                                // ignore: invalid_use_of_protected_member
                                parentState.setState(() {
                                  parentState._selectedIndex = 3; // Swaps view tab seamlessly
                                });
                              }
                            }
                          } else {
                            // 4. Insufficient Fallback: Prompt user to clear token block via ad generation
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text("Insufficient Balance! Simulate an ad to earn connection tokens."),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text("Connect", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCards(String learningHours, double walletBalance) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _statItem("Learning", learningHours, Colors.blue),
          const SizedBox(width: 10),
          // Clean dynamic presentation showing calculations as real USD values
          _statItem("Wallet Balance", "\$${walletBalance.toStringAsFixed(2)}", Colors.green),
        ],
      ),
    );
  }

  Widget _statItem(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
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