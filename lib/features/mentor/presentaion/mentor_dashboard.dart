import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/welcome_screen.dart'; // Direct route for clean log out

class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});

  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard> {
  bool _isOnline = false; // Tracks if the mentor is visible to students

  // Function to simulate earning money by teaching a session unit
  Future<void> _simulateTeachingEarnings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      // Simulating a 10-minute session reward block ($1.00 gross revenue)
      await userDoc.update({
        'mentorEarningsUSD': FieldValue.increment(1.00),
      });
    }
  }

  // Function to toggle the mentor's online availability state in Firestore
  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _isOnline = value);
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      await userDoc.update({
        'isOnline': value,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: value ? Colors.green : Colors.grey,
            content: Text(value ? "You are now live! Students can see you." : "You are now offline."),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF333697)),
            onPressed: () async {
              // 1. Turn off online presence tracking flag before logging out safely
              if (_isOnline) {
                await _toggleOnlineStatus(false);
              }
              // 2. Clear authentication token state
              await FirebaseAuth.instance.signOut();
              
              // 3. Clear workspace view memory and bounce back to entry gate
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: uid != null
            ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
            : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          double mentorEarningsUSD = 0.00;
          double connectionRatePerMin = 0.10;
          String expertiseTag = "Flutter Developer";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            mentorEarningsUSD = (data['mentorEarningsUSD'] ?? 0.0).toDouble();
            connectionRatePerMin = (data['connectionRatePerMin'] ?? 0.10).toDouble();
            expertiseTag = data['expertiseTag'] ?? 'Expert Systems Engineer';
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ONLINE/OFFLINE PRESENCE CARD ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isOnline 
                          ? Colors.greenAccent.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _isOnline ? Colors.greenAccent : Colors.grey.shade400,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      // FIXED: Corrected layout parameter syntax mapping
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: _isOnline ? Colors.green : Colors.grey,
                              size: 14,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isOnline ? "Status: Accept Requests" : "Status: Dormant (Offline)",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _isOnline ? Colors.green.shade700 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isOnline,
                          // FIXED: Replaced deprecated activeColor configuration properties
                          activeThumbColor: const Color(0xFF333697),
                          activeTrackColor: const Color(0xFF333697).withValues(alpha: 0.4),
                          onChanged: _toggleOnlineStatus,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- METRIC ROW ---
                  Row(
                    children: [
                      _mentorStatItem("Total Earnings", "\$${mentorEarningsUSD.toStringAsFixed(2)}", Colors.green),
                      const SizedBox(width: 12),
                      _mentorStatItem("Charge Rate", "\$${connectionRatePerMin.toStringAsFixed(2)}/min", Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // --- SIMULATED INCOMING ENGINE TRACKER ---
                  const Text(
                    "Session Controls",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Active Profile Badge: $expertiseTag",
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Simulate a completed mentoring connection payload to test your Firestore ledger balances.",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isOnline ? _simulateTeachingEarnings : null,
                            icon: const Icon(Icons.videocam, color: Colors.white),
                            label: const Text(
                              "Simulate 10-Min Session (Earn \$1.00)",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF333697),
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        if (!_isOnline)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              "*You must toggle your availability status to Online to accept connections.",
                              style: TextStyle(color: Colors.redAccent, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mentorStatItem(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}