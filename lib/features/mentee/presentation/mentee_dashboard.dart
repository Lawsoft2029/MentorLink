import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/subscription_screen.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/welcome_screen.dart';
import 'package:mentorlinks_app_project/features/chat/presentation/chat_screen.dart'; // <-- Added import for Chat
import 'package:mentorlinks_app_project/shared/widgets/star_rating_widget.dart';
import 'wallet_screen.dart';
import 'vault_screen.dart';
import 'live_session_screen.dart';
import 'mentee_subscription_screen.dart';
import 'package:mentorlinks_app_project/features/gamification/presentation/unlock_study_time_screen.dart';

class MenteeDashboard extends StatefulWidget {
  const MenteeDashboard({super.key});

  @override
  State<MenteeDashboard> createState() => _MenteeDashboardState();
}

class _MenteeDashboardState extends State<MenteeDashboard> {
  int _selectedIndex = 0;

  // The pages used for the Bottom Navigation
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreenContent(
        onNavigateToLive: () => setState(() => _selectedIndex = 3),
      ),
      const WalletScreen(),
      const VaultScreen(),
      const LiveSessionScreen(sessionId: 'default_session', role: 'mentee'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
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
  const HomeScreenContent({super.key, required this.onNavigateToLive});

  final VoidCallback onNavigateToLive;

  Future<void> _watchAdAndEarn(BuildContext context) async {
    // ROUTED TO UNLOCK STUDY TIME SCREEN TO HANDLE WEB/MOBILE AD REWARDS
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UnlockStudyTimeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentee Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium, color: Colors.amber),
            tooltip: 'Upgrade / Top Up',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF333697)),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: uid != null
            ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots()
            : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          double walletBalanceUSD = 0.00;
          double walletMinutes = 0.0;
          String userTier = 'Freemium';
          String learningHours = "12 hrs";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            walletBalanceUSD = (data['walletBalanceUSD'] ?? 0.0).toDouble();
            walletMinutes = (data['walletMinutes'] ?? 0.0).toDouble();
            userTier = data['userTier'] ?? 'Freemium';

            if (data['totalMinutesLearned'] != null) {
              int mins = (data['totalMinutesLearned'] as num).toInt();

              learningHours = mins >= 60
                  ? "${(mins / 60).toStringAsFixed(1)} hrs"
                  : "$mins mins";
            }
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- PRO UPGRADE BANNER ---
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MenteeSubscriptionScreen(),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF333697), Color(0xFF5C62D6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 30),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Upgrade to MentorLinks Pro",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Enjoy ad-free learning & priority matching.",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),

                _buildStatCards(learningHours, walletBalanceUSD, walletMinutes),

                if (userTier == 'Freemium')
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
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
                                style: TextStyle(
                                  color: Colors.green[300],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Watch short ads to unlock 1-hour study passes for your sessions.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _watchAdAndEarn(context),
                              icon: const Icon(
                                Icons.play_circle_filled,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Watch Ad (Unlock Study Pass)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF333697),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Available Mentors",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF333697),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: const Text("Expert Developer"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Flutter • Dart • Firebase\nRate: \$0.10/min",
                          ),
                          const SizedBox(height: 4),
                          StarRatingWidget(rating: 4.8, reviewCount: 128),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: TextButton(
                        onPressed: () {
                          // Navigate to Chat Screen to discuss goals and schedule first!
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatScreen(
                                chatRoomId: "sample_mentor_mentee_room",
                                receiverName: "Expert Developer",
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          "Connect",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333697),
                          ),
                        ),
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

  Widget _buildStatCards(
    String learningHours,
    double walletBalance,
    double walletMinutes,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _statItem("Learning", learningHours, Colors.blue),
          const SizedBox(width: 8),
          _statItem(
            "Study Time",
            "${walletMinutes.toStringAsFixed(0)} mins",
            Colors.deepPurple,
          ),
          const SizedBox(width: 8),
          _statItem(
            "Wallet",
            "\$${walletBalance.toStringAsFixed(2)}",
            Colors.green,
          ),
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
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
