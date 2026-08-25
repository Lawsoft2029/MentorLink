import 'dojah_verification_service.dart';
import 'persona_verification_service.dart';

class EnterpriseVerificationRouter {
  final DojahVerificationService _dojahService = DojahVerificationService();
  final PersonaVerificationService _personaService = PersonaVerificationService();

  Future<Map<String, dynamic>> verifyCompanyEntity({
    required String jurisdiction,
    required String companyName,
    required String registrationNumber,
  }) async {
    // 1. Route to Dojah if it's an African/Nigerian entity
    if (jurisdiction.contains('Nigeria') || jurisdiction.contains('Africa')) {
      return await _dojahService.verifyBusinessRegistration(
        companyName: companyName,
        registrationNumber: registrationNumber,
      );
    } 
    // 2. Route to Persona if it's United States, UK, or International
    else {
      String countryCode = 'US'; // Default fallback
      if (jurisdiction.contains('United Kingdom') || jurisdiction.contains('UK')) {
        countryCode = 'GB';
      } else if (jurisdiction.contains('United States') || jurisdiction.contains('Delaware')) {
        countryCode = 'US';
      }

      return await _personaService.verifyGlobalBusiness(
        companyName: companyName,
        countryCode: countryCode,
        registrationNumber: registrationNumber,
      );
    }
  }
}