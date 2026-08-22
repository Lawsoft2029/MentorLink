import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // IMPORT DOTENV
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FlutterwavePaymentService {
  // Pulls the public key securely from the hidden .env file
  static String get _sandboxPublicKey => dotenv.env['FLUTTERWAVE_PUBLIC_KEY'] ?? '';

  /// Triggers the Flutterwave Inline Card Payment modal for Mentee Pro Subscriptions
  static Future<void> startProSubscriptionPayment({
    required BuildContext context,
    required double amountUSD,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast(context, "User unauthenticated.", Colors.red);
      return;
    }

    if (_sandboxPublicKey.isEmpty) {
      _showToast(context, "Error: Flutterwave Public Key missing from environment.", Colors.red);
      return;
    }

    final String userEmail = user.email ?? "mentee@mentorlinks.com";
    final String userName = user.displayName ?? "MentorLinks Student";
    final String txRef = "ML_PRO_${DateTime.now().millisecondsSinceEpoch}";

    final Customer customer = Customer(
      email: userEmail,
      name: userName,
      phoneNumber: "08000000000",
    );

    final Flutterwave flutterwave = Flutterwave(
      publicKey: _sandboxPublicKey,
      currency: "USD", // Change to "NGN" if testing local fiat currency
      amount: amountUSD.toStringAsFixed(2),
      txRef: txRef,
      customer: customer,
      paymentOptions: "card, ussd, banktransfer",
      redirectUrl: "https://flutterwave.com", // Required redirect URL handler
      customization: Customization(
        title: "MentorLinks Pro Academy",
        description: "Monthly Unlimited Access Pass",
        logo: "https://raw.githubusercontent.com/Lawsoft2029/pay/main/assets/app_logo.png",
      ),
      isTestMode: true, // Sandbox test mode enabled
    );

    try {
      final ChargeResponse response = await flutterwave.charge(context);

      if (response.status == "successful" || response.success == true) {
        // Update user tier in Firestore upon successful payment verification
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'userTier': 'Premium',
          'isPremium': true,
          'subscriptionDate': FieldValue.serverTimestamp(),
          'lastTxRef': response.txRef,
          'paymentGateway': 'Flutterwave Card',
        });

        if (context.mounted) {
          _showToast(context, "Payment successful! Welcome to MentorLinks Pro.", Colors.green);
          Navigator.pop(context); // Close subscription screen
        }
      } else {
        if (context.mounted) {
          _showToast(context, "Payment cancelled or incomplete.", Colors.orange);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, "Payment failed: $e", Colors.red);
      }
    }
  }

  static void _showToast(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }
}