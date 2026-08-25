import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DojahVerificationService {
  final String _baseUrl = 'https://sandbox.dojah.io/api/v1'; // Change to api.dojah.io for live production

  /// Verifies a business registration number (e.g., CAC in Nigeria) using Dojah API
  Future<Map<String, dynamic>> verifyBusinessRegistration({
    required String companyName,
    required String registrationNumber,
  }) async {
    final String apiKey = dotenv.env['DOJAH_API_KEY'] ?? '';
    final String appId = dotenv.env['DOJAH_APP_ID'] ?? '';

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/kyb/cac?rc_number=$registrationNumber&company_name=$companyName'),
        headers: {
          'Authorization': apiKey,
          'AppId': appId,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['entity'] ?? data,
        };
      } else {
        return {
          'success': false,
          'message': 'Verification failed with status code ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error during Dojah verification: $e',
      };
    }
  }
}