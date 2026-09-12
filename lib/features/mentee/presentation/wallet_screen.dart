import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text(
          "Learning Wallet",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      // Wrapped body with StreamBuilder to pull live operational telemetry from Firestore
      body: StreamBuilder<DocumentSnapshot>(
        stream: uid != null
            ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots()
            : null,
        builder: (context, snapshot) {
          double activeBalance = 0.00;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            activeBalance = (data['walletBalanceUSD'] ?? 0.0).toDouble();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 1. DYNAMIC LEARNER BALANCE CARD (Passes live value down)
                _buildBalanceCard(activeBalance),

                const SizedBox(height: 30),

                // 2. FUNDING OPTIONS (For the Learner to add money)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Top up Balance",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _topUpOption("\$5.00"),
                    _topUpOption("\$10.00"),
                    _topUpOption("\$20.00"),
                  ],
                ),

                const SizedBox(height: 30),

                // 3. SPENDING LOG (Where the learner's money went)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Learning Expenses",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 15),
                _historyItem(
                  "Session: Flutter Debugging",
                  "-\$0.45",
                  "10 mins ago",
                  Colors.redAccent,
                ),
                _historyItem(
                  "Session: IoT Hardware Setup",
                  "-\$1.20",
                  "Today, 10:00 AM",
                  Colors.redAccent,
                ),
                _historyItem(
                  "Simulated Ad Reward",
                  "+\$0.05",
                  "Real-time Tracker",
                  Colors.green,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Modified constructor to pass live database stream value straight into layout view
  Widget _buildBalanceCard(double balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF333697),
        borderRadius: BorderRadius.circular(25),
        image: const DecorationImage(
          image: NetworkImage(
            'https://www.transparenttextures.com/patterns/cubes.png',
          ), // Subtle professional texture
          opacity: 0.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Current Balance",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          // Outputs real-time matching currency matching home tab logic
          Text(
            "\$${balance.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              _actionBtn(Icons.add, "Deposit"),
              const SizedBox(width: 15),
              _actionBtn(Icons.history, "Statements"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topUpOption(String amount) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          // ignore: deprecated_member_use
          border: Border.all(color: const Color(0xFF333697).withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF333697),
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyItem(String title, String amount, String time, Color color) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(time),
        trailing: Text(
          amount,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
