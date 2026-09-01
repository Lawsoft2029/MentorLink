import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTopUpScreen extends StatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;

  // Simulate Flutterwave Fiat Top-Up Trigger
  void _processFlutterwavePayment() async {
    if (_amountController.text.isEmpty) return;
    setState(() => _isProcessing = true);

    // Integrate actual flutterwave_standard package payload here
    // Example: FlutterwaveUIStyle().showPaymentModal(context: context, ...)
    await Future.delayed(const Duration(seconds: 2)); // Mock network call

    double addedMinutes = double.parse(_amountController.text) * 10; // e.g., $1 = 10 minutes
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'walletMinutes': FieldValue.increment(addedMinutes),
      });
    }

    setState(() => _isProcessing = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Fiat Top-Up Successful! Minutes added to wallet.")),
    );
    Navigator.pop(context);
  }

  // Simulate NOWPayments Crypto Checkout Trigger
  void _processCryptoPayment() async {
    if (_amountController.text.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final amount = _amountController.text;
      // POST request to NOWPayments /v1/payment endpoint
      final response = await Future.delayed(const Duration(seconds: 2), () {
        // In production, replace with actual HTTP POST to:
        // https://api.nowpayments.io/v1/payment
        // with headers: {"x-api-key": YOUR_API_KEY}
        // body: {"price_amount": amount, "price_currency": "usd", "pay_currency": "eth"}
        return {"payment_id": "pay_123", "pay_address": "0xMOCK_CRYPTO_VAULT_ADDRESS_9128", "pay_amount": amount};
      });

      setState(() => _isProcessing = false);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("NOWPayments Crypto Invoice"),
          content: Text("Send exact crypto amount to address: ${response['pay_address']}"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Top-Up Learning Minutes")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter Amount (USD)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: "\$",
                border: OutlineInputBorder(),
                hintText: "10.00",
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                icon: const Icon(Icons.credit_card),
                label: const Text("Pay with Flutterwave (Card/Bank)"),
                onPressed: _isProcessing ? null : _processFlutterwavePayment,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                icon: const Icon(Icons.currency_bitcoin),
                label: const Text("Pay with NOWPayments (Crypto)"),
                onPressed: _isProcessing ? null : _processCryptoPayment,
              ),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ]
          ],
        ),
      ),
    );
  }
}