// ignore_for_file: prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WithdrawFundsDialog extends StatefulWidget {
  final double currentBalance;

  const WithdrawFundsDialog({
    super.key,
    required this.currentBalance,
  });

  @override
  State<WithdrawFundsDialog> createState() => _WithdrawFundsDialogState();
}

class _WithdrawFundsDialogState extends State<WithdrawFundsDialog> {
  String _selectedMethod = 'flutterwave'; // 'flutterwave' or 'nowpayments'
  final TextEditingController _amountController = TextEditingController();
  
  // Bank fields (Flutterwave)
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();

  // Crypto fields (NOWPayments)
  final TextEditingController _cryptoAddressController = TextEditingController();
  String _selectedCrypto = 'USDT-TRC20'; // Default crypto currency

  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _cryptoAddressController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showToast("Please enter a withdrawal amount.", Colors.red);
      return;
    }

    final double? requestedAmount = double.tryParse(amountText);
    if (requestedAmount == null || requestedAmount <= 0) {
      _showToast("Please enter a valid positive amount.", Colors.red);
      return;
    }

    if (requestedAmount > widget.currentBalance) {
      _showToast("Amount exceeds your available balance (\$" + widget.currentBalance.toStringAsFixed(2) + ").", Colors.red);
      return;
    }

    // Validate method inputs
    if (_selectedMethod == 'flutterwave') {
      if (_bankNameController.text.trim().isEmpty || _accountNumberController.text.trim().isEmpty) {
        _showToast("Please fill in both Bank Name and Account Number.", Colors.red);
        return;
      }
    } else {
      if (_cryptoAddressController.text.trim().isEmpty) {
        _showToast("Please enter your wallet address.", Colors.red);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User unauthenticated.");

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // Deduct balance atomically
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) throw Exception("Mentor record not found.");

        double currentBalance = (snapshot.data()?['mentorEarningsUSD'] ?? 0.0).toDouble();

        if (requestedAmount > currentBalance) {
          throw Exception("Insufficient balance.");
        }

        transaction.update(userRef, {
          'mentorEarningsUSD': currentBalance - requestedAmount,
        });
      });

      // Save payout request payload for backend execution (Flutterwave or NOWPayments worker)
      await FirebaseFirestore.instance.collection('payouts').add({
        'mentorId': uid,
        'amountUSD': requestedAmount,
        'gateway': _selectedMethod, // 'flutterwave' or 'nowpayments'
        'details': _selectedMethod == 'flutterwave'
            ? {
                'bankName': _bankNameController.text.trim(),
                'accountNumber': _accountNumberController.text.trim(),
              }
            : {
                'cryptoTicker': _selectedCrypto,
                'walletAddress': _cryptoAddressController.text.trim(),
              },
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showToast("Withdrawal request submitted successfully!", Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showToast("Withdrawal failed: $e", Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF00796B);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Withdraw Funds", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            "Available Balance: \$${widget.currentBalance.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 13, color: primaryTeal, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Gateway", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),

            // Gateway Selection Buttons
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text("Flutterwave", style: TextStyle(fontSize: 11)),
                    selected: _selectedMethod == 'flutterwave',
                    selectedColor: primaryTeal.withValues(alpha: 0.2),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedMethod = 'flutterwave');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text("NOWPayments", style: TextStyle(fontSize: 11)),
                    selected: _selectedMethod == 'nowpayments',
                    selectedColor: primaryTeal.withValues(alpha: 0.2),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedMethod = 'nowpayments');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Input
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Amount (USD)",
                hintText: "e.g. 50.00",
                prefixIcon: const Icon(Icons.attach_money, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // Dynamic Form based on Gateway
            if (_selectedMethod == 'flutterwave') ...[
              const Text("Local Bank Account Details", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: "Bank Name",
                  hintText: "e.g. Access Bank, GTBank, Kuda",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Account Number",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ] else ...[
              const Text("Cryptocurrency Wallet Details", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCrypto,
                decoration: InputDecoration(
                  labelText: "Select Crypto",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'USDT-TRC20', child: Text('USDT (TRC-20)')),
                  DropdownMenuItem(value: 'BTC', child: Text('Bitcoin (BTC)')),
                  DropdownMenuItem(value: 'ETH', child: Text('Ethereum (ETH)')),
                ],
                onChanged: (val) => setState(() => _selectedCrypto = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cryptoAddressController,
                decoration: InputDecoration(
                  labelText: "Wallet Address",
                  hintText: "Paste recipient address...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSubmitting ? null : _submitWithdrawal,
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Confirm Payout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}