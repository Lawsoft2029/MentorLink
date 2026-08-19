import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  Future<void> _upgradeToPremium(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'userTier': 'Premium',
        'walletBalanceUSD': FieldValue.increment(10.00), // Bonus starting credits
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully upgraded to Premium Tier!")),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _buyTokenCredits(BuildContext context, double amount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'walletBalanceUSD': FieldValue.increment(amount),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully added \$$amount to your wallet!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Subscription & Token Store"),
        backgroundColor: const Color(0xFF333697),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Upgrade Your Experience",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Choose a subscription tier or top up your session balance to keep learning without interruptions.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 30),
            
            // Premium Tier Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("MentorLinks Premium", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333697))),
                        Chip(label: Text("\$9.99 / mo", style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF333697)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text("• Unlimited priority mentor matching\n• Zero per-minute balance deduction\n• Includes \$10 starting token credit"),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _upgradeToPremium(context),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333697), minimumSize: const Size(double.infinity, 45)),
                      child: const Text("Upgrade to Premium", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            
            const Text("Quick Token Top-Ups", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => _buyTokenCredits(context, 2.00),
                  child: const Text("Add \$2.00"),
                ),
                OutlinedButton(
                  onPressed: () => _buyTokenCredits(context, 5.00),
                  child: const Text("Add \$5.00"),
                ),
                OutlinedButton(
                  onPressed: () => _buyTokenCredits(context, 10.00),
                  child: const Text("Add \$10.00"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}