import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'enterprise_register_screen.dart'; // IMPORTED THE ENTERPRISE REGISTRATION SCREEN

class TierSelectionScreen extends StatelessWidget {
  const TierSelectionScreen({super.key});

  // Function to update the user's tier in Firebase for Freemium / Premium
  Future<void> _selectTier(BuildContext context, String tier) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'userTier': tier,
        'isPremium': tier != 'Freemium',
        'walletBalanceUSD': tier == 'Freemium' ? 0.00 : 20.00,
        'totalMinutesLearned': 0,
      }, SetOptions(merge: true));
      
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/mentee-dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Choose Your Path", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "How would you like to access mentorship?",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            
            // --- FREEMIUM CARD ---
            _buildTierCard(
              context,
              title: "Freemium",
              price: "\$0",
              description: "Exchange attention for knowledge.",
              features: ["Earn credits via Ads", "Community Support", "Full Access"],
              color: Colors.greenAccent,
              onTap: () => _selectTier(context, "Freemium"),
            ),
            
            const SizedBox(height: 20),

            // --- PREMIUM CARD ---
            _buildTierCard(
              context,
              title: "Premium",
              price: "\$19.99",
              description: "Fast-track your learning journey.",
              features: ["No Ads", "Priority Mentors", "Direct Connect"],
              color: Colors.blueAccent,
              isPopular: true,
              onTap: () => _selectTier(context, "Premium"),
            ),
            const SizedBox(height: 20),

            // --- ENTERPRISE CARD (ROUTES TO REGISTRATION FORM) ---
            _buildTierCard(
              context,
              title: "Enterprise",
              price: "\$499 / mo",
              description: "For Hubs, Schools, and Teams.",
              features: ["Bulk User Licenses", "Admin Dashboard", "Private Mentorship", "Custom API Access"],
              color: Colors.purpleAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EnterpriseRegisterScreen()),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(BuildContext context, 
      {required String title, required String price, required String description, 
       required List<String> features, required Color color, required VoidCallback onTap, bool isPopular = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isPopular ? color : Colors.transparent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular) const Text("MOST POPULAR", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
          Text(title, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(price, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const Divider(color: Colors.white10, height: 30),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(children: [Icon(Icons.check_circle, color: color, size: 16), const SizedBox(width: 10), Text(f, style: const TextStyle(color: Colors.white))]),
          )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Select Plan", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}