import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NowPaymentsSandboxService {
  static const String _sandboxUrl = "https://api-sandbox.nowpayments.io/v1";

  static Future<void> createSandboxCryptoInvoice({
    required BuildContext context,
    required double amountUSD,
    required double minutesToAdd,
    required String payCurrency, // e.g., 'usdttrc20', 'btc'
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Pulling the API key directly from your .env file
    final String apiKey = dotenv.env['NOWPAYMENTS_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: NOWPayments API Key missing from environment."),
        ),
      );
      return;
    }

    final url = Uri.parse('$_sandboxUrl/invoice');
    final orderId = "ML_CRYPTO_${DateTime.now().millisecondsSinceEpoch}";

    try {
      final response = await http.post(
        url,
        headers: {'x-api-key': apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'price_amount': amountUSD,
          'price_currency': 'usd',
          'pay_currency': payCurrency,
          'order_id': orderId,
          'order_description': 'MentorLinks Sandbox Crypto Top-Up',
          'success_url': 'https://mentorlinks.com/payment-success',
          'cancel_url': 'https://mentorlinks.com/payment-cancel',
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String invoiceUrl = data['invoice_url'];

        // Sandbox immediate credit for testing local loop
        await _creditUserWallet(user.uid, minutesToAdd);

        final Uri uri = Uri.parse(invoiceUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        debugPrint("NOWPayments Sandbox error: ${response.body}");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to generate crypto sandbox invoice."),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Crypto sandbox connection error: $e");
    }
  }

  static Future<void> _creditUserWallet(String uid, double minutes) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await userRef.update({
      'walletMinutes': FieldValue.increment(minutes),
      'totalMinutesPurchased': FieldValue.increment(minutes),
    });
  }
}
