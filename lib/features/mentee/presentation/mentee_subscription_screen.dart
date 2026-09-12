import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MenteeSubscriptionScreen extends StatefulWidget {
  const MenteeSubscriptionScreen({super.key});

  @override
  State<MenteeSubscriptionScreen> createState() =>
      _MenteeSubscriptionScreenState();
}

class _MenteeSubscriptionScreenState extends State<MenteeSubscriptionScreen> {
  bool _isProcessing = false;
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _processCardPayment() async {
    if (_cardNumberController.text.trim().length < 15 ||
        _expiryController.text.trim().isEmpty ||
        _cvvController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid card details."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Simulate secure card verification / Flutterwave gateway processing delay
      await Future.delayed(const Duration(seconds: 2));

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in.");

      // Update user tier in Firestore to Premium
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'userTier': 'Premium',
        'isPremium': true,
        'subscriptionDate': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment successful! Welcome to MentorLinks Pro."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Return to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF333697);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Upgrade to Pro Academy",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryIndigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pro Banner Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF333697), Color(0xFF5C62D6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 36),
                  SizedBox(height: 12),
                  Text(
                    "MentorLinks Pro Plan",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Ad-free learning, priority mentor queue matching, unlimited code canvas whiteboarding, and verifiable offline completion certificates.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "\$9.99 / month (~₦15,000 local equivalent)",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            const Text(
              "Secure Card Payment (Flutterwave Gateway)",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: primaryIndigo,
              ),
            ),
            const SizedBox(height: 16),

            // Card Number
            TextField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Card Number",
                hintText: "4234 5678 9012 3456",
                prefixIcon: const Icon(Icons.credit_card),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Expiry & CVV Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryController,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: "Expiry Date",
                      hintText: "MM/YY",
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "CVV",
                      hintText: "123",
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryIndigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isProcessing ? null : _processCardPayment,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Pay \$9.99 & Activate Pro",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
