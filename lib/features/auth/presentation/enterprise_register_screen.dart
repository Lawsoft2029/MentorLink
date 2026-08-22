// ignore_for_file: deprecated_member_use, unused_local_variable

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../enterprise/presentation/enterprise_dashboard_screen.dart';

class EnterpriseRegisterScreen extends StatefulWidget {
  const EnterpriseRegisterScreen({super.key});

  @override
  State<EnterpriseRegisterScreen> createState() => _EnterpriseRegisterScreenState();
}

class _EnterpriseRegisterScreenState extends State<EnterpriseRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _businessEmailController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  String _selectedCountryCode = 'NG'; // Default jurisdiction
  bool _isSubmitting = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _businessEmailController.dispose();
    _taxIdController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _submitEnterpriseRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _businessEmailController.text.trim();
    // Anti-fraud: Block free personal webmail domains for B2B enterprise tier
    if (email.contains('gmail.com') || email.contains('yahoo.com') || email.contains('outlook.com')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please use an official company/business email address."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User unauthenticated.");

      // Save enterprise registration profile to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'userTier': 'Enterprise',
        'isPremium': true,
        'companyName': _companyNameController.text.trim(),
        'businessEmail': email,
        'jurisdiction': _selectedCountryCode,
        'taxOrRegistrationId': _taxIdController.text.trim(),
        'website': _websiteController.text.trim(),
        'verificationStatus': 'PendingVerification', // Set to pending compliance review
        'walletBalanceUSD': 500.00,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Enterprise registration submitted successfully! Under review."),
            backgroundColor: Colors.green,
          ),
        );
        // Route to Enterprise Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EnterpriseDashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const corporateBlue = Color(0xFF1E3A8A);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Enterprise Business Verification", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Secure Corporate Onboarding",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "To prevent fraud and protect our corporate tier, please verify your business details below.",
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 30),

              // Company Name
              TextFormField(
                controller: _companyNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Company / Legal Business Name",
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.business, color: Colors.white70),
                ),
                validator: (val) => val == null || val.isEmpty ? "Please enter company name" : null,
              ),
              const SizedBox(height: 16),

              // Business Jurisdiction Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCountryCode,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Business Country Jurisdiction",
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.public, color: Colors.white70),
                ),
                items: const [
                  DropdownMenuItem(value: 'NG', child: Text('Nigeria (CAC)')),
                  DropdownMenuItem(value: 'US', child: Text('United States (EIN)')),
                  DropdownMenuItem(value: 'GB', child: Text('United Kingdom (Companies House)')),
                  DropdownMenuItem(value: 'EU', child: Text('European Union (VAT / Reg)')),
                  DropdownMenuItem(value: 'GLOBAL', child: Text('Other Global Region')),
                ],
                onChanged: (val) => setState(() => _selectedCountryCode = val!),
              ),
              const SizedBox(height: 16),

              // Business Email
              TextFormField(
                controller: _businessEmailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Official Business Email",
                  hintText: "admin@company.com",
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email, color: Colors.white70),
                ),
                validator: (val) => val == null || !val.contains('@') ? "Enter a valid corporate email" : null,
              ),
              const SizedBox(height: 16),

              // Tax / Registration ID
              TextFormField(
                controller: _taxIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Tax ID / Business Registration Number",
                  hintText: "e.g. CAC / EIN / VAT Number",
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.badge, color: Colors.white70),
                ),
                validator: (val) => val == null || val.isEmpty ? "Please enter your business registration ID" : null,
              ),
              const SizedBox(height: 16),

              // Website URL
              TextFormField(
                controller: _websiteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Company Website URL",
                  hintText: "https://www.company.com",
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.language, color: Colors.white70),
                ),
                validator: (val) => val == null || val.isEmpty ? "Please enter company website URL" : null,
              ),
              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submitEnterpriseRegistration,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "Verify & Access Enterprise Console",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}