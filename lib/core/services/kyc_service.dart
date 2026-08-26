class KycService {
  // Simulates verifying a business entity locally or globally via sandbox
  static Future<bool> verifyBusinessEntity({
    required String countryCode,
    required String businessName,
    required String registrationNumber,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // For testing: let's say any registration number longer than 5 characters passes successfully
    if (registrationNumber.trim().length >= 5 && businessName.trim().isNotEmpty) {
      return true; 
    } else {
      throw Exception("Invalid registration details for $countryCode");
    }
  }
}