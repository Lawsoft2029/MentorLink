// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MentorPayoutScreen extends StatefulWidget {
  const MentorPayoutScreen({super.key});

  @override
  State<MentorPayoutScreen> createState() => _MentorPayoutScreenState();
}

class _MentorPayoutScreenState extends State<MentorPayoutScreen> {
  String _selectedMethod = 'flutterwave'; // 'flutterwave' or 'crypto'
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _cryptoAddressController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _cryptoAddressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _processPayout() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a withdrawal amount."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final double? requestedAmount = double.tryParse(amountText);
    if (requestedAmount == null || requestedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid amount."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDocRef);
        if (!snapshot.exists) throw Exception("User record not found.");

        double currentBalance = (snapshot.data()?['mentorEarningsUSD'] ?? 0.0)
            .toDouble();

        if (requestedAmount > currentBalance) {
          throw Exception("Insufficient earnings balance.");
        }

        // Deduct balance and log payout request
        transaction.update(userDocRef, {
          'mentorEarningsUSD': currentBalance - requestedAmount,
        });
      });

      // Log transaction history
      await FirebaseFirestore.instance.collection('payouts').add({
        'mentorId': uid,
        'amountUSD': requestedAmount,
        'method': _selectedMethod,
        'details': _selectedMethod == 'flutterwave'
            ? 'Bank: ${_bankNameController.text}, Acc: ${_accountNumberController.text}'
            : 'USDT Address: ${_cryptoAddressController.text}',
        'status': 'Processing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payout request submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payout failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00796B); // Professional Mentor Teal

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Mentor Payout & Earnings",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Payout Method",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333697),
              ),
            ),
            const SizedBox(height: 12),

            // Method Toggle Selector
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text(
                      "Flutterwave (Fiat)",
                      style: TextStyle(fontSize: 13),
                    ),
                    value: 'flutterwave',
                    groupValue: _selectedMethod,
                    activeColor: primaryColor,
                    onChanged: (val) => setState(() => _selectedMethod = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text(
                      "NOWPayments (Crypto)",
                      style: TextStyle(fontSize: 13),
                    ),
                    value: 'crypto',
                    groupValue: _selectedMethod,
                    activeColor: primaryColor,
                    onChanged: (val) => setState(() => _selectedMethod = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Withdrawal Amount (USD)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Form Fields based on method
            if (_selectedMethod == 'flutterwave') ...[
              TextField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: "Bank Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Account Number",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.numbers),
                ),
              ),
            ] else ...[
              TextField(
                controller: _cryptoAddressController,
                decoration: InputDecoration(
                  labelText: "USDT (TRC-20) Wallet Address",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.currency_bitcoin),
                ),
              ),
            ],
            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _processPayout,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Request Payout",
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
