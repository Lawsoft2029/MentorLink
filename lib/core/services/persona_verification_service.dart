import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PersonaVerificationService {
  final String _baseUrl = 'https://api.withpersona.com/api/v1';

  /// Verifies international businesses using Persona's Database Business Verification API
  Future<Map<String, dynamic>> verifyGlobalBusiness({
    required String companyName,
    required String countryCode, // e.g., 'US', 'GB'
    required String registrationNumber,
  }) async {
    final String apiKey = dotenv.env['PERSONA_API_KEY'] ?? '';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verification/database-businesses'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "data": {
            "attributes": {
              "company-name": companyName,
              "country-code": countryCode,
              "registration-number": registrationNumber,
            },
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? data};
      } else {
        return {
          'success': false,
          'message':
              'Persona verification failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error during Persona verification: $e',
      };
    }
  }
}
