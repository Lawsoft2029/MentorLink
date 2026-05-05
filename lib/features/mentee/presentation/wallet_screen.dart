import 'package:flutter/material.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text("Learning Wallet", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. LEARNER BALANCE CARD
            _buildBalanceCard(),

            const SizedBox(height: 30),

            // 2. FUNDING OPTIONS (For the Learner to add money)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Top up Balance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _topUpOption("₦2k"),
                _topUpOption("₦5k"),
                _topUpOption("₦10k"),
              ],
            ),

            const SizedBox(height: 30),

            // 3. SPENDING LOG (Where the learner's money went)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Learning Expenses", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 15),
            _historyItem("Session: Flutter Debugging", "-₦450", "10 mins ago", Colors.redAccent),
            _historyItem("Session: IoT Hardware Setup", "-₦1,200", "Today, 10:00 AM", Colors.redAccent),
            _historyItem("Wallet Funded", "+₦5,000", "Yesterday", Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF333697),
        borderRadius: BorderRadius.circular(25),
        image: const DecorationImage(
          image: NetworkImage('https://www.transparenttextures.com/patterns/cubes.png'), // Subtle professional texture
          opacity: 0.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Current Balance", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          const Text("₦7,340.50", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          Row(
            children: [
              _actionBtn(Icons.add, "Deposit"),
              const SizedBox(width: 15),
              _actionBtn(Icons.history, "Statements"),
            ],
          )
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          border: Border.all(color: const Color(0xFF333697).withOpacity(0.2)),
        ),
        child: Center(
          child: Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333697))),
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
        trailing: Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}