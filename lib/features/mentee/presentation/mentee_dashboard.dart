import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/subscription_screen.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/welcome_screen.dart';
import 'package:mentorlinks_app_project/shared/widgets/star_rating_widget.dart';
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
    const LiveSessionScreen(sessionId: 'default_session', role: 'mentee'),
  ];

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
  const HomeScreenContent({super.key});

  Future<void> _watchAdAndEarn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      await userDoc.update({'walletBalanceUSD': FieldValue.increment(0.05)});
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
          String userTier = 'Freemium';
          String learningHours = "12 hrs";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            walletBalanceUSD = (data['walletBalanceUSD'] ?? 0.0).toDouble();
            userTier = data['userTier'] ?? 'Freemium';

            if (data['totalMinutesLearned'] != null) {
              int mins = data['totalMinutesLearned'];
              learningHours = mins >= 60
                  ? "${(mins / 60).toStringAsFixed(1)} hrs"
                  : "$mins mins";
            }
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatCards(learningHours, walletBalanceUSD),

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
                            "Watch short ads to load tokens into your operational wallet instantly.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _watchAdAndEarn,
                              icon: const Icon(
                                Icons.play_circle_filled,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Simulate Ad (Earn \$0.05)",
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
                    const double mentorRatePerMin = 0.10;

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF333697),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: const Text("Expert Developer"),
                      // INTEGRATED STAR RATING WIDGET IN SUBTITLE
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Flutter • Dart • Firebase\nRate: \$0.10/min",
                          ),
                          const SizedBox(height: 4),
                          StarRatingWidget(
                            rating:
                                4.8, // You can link this dynamically from Firestore later
                            reviewCount: 128,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: TextButton(
                        onPressed: () async {
                          if (walletBalanceUSD >= mentorRatePerMin) {
                            if (uid != null) {
                              final userDoc = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid);
                              await userDoc.update({
                                'walletBalanceUSD': FieldValue.increment(
                                  -mentorRatePerMin,
                                ),
                              });
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Deducting credit... Routing to Live Session room.",
                                  ),
                                ),
                              );

                              final parentState = context
                                  .findAncestorStateOfType<
                                    _MenteeDashboardState
                                  >();
                              if (parentState != null) {
                                // ignore: invalid_use_of_protected_member
                                parentState.setState(() {
                                  parentState._selectedIndex = 3;
                                });
                              }
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text(
                                    "Insufficient Balance! Simulate an ad to earn connection tokens.",
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          "Connect",
                          style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildStatCards(String learningHours, double walletBalance) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _statItem("Learning", learningHours, Colors.blue),
          const SizedBox(width: 10),
          _statItem(
            "Wallet Balance",
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
