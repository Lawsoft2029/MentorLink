import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EnterpriseRegistrationScreen extends StatefulWidget {
  const EnterpriseRegistrationScreen({super.key});

  @override
  State<EnterpriseRegistrationScreen> createState() => _EnterpriseRegistrationScreenState();
}

class _EnterpriseRegistrationScreenState extends State<EnterpriseRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();
  final TextEditingController _corporateEmailController = TextEditingController();
  final TextEditingController _seatCountController = TextEditingController();
  
  String _selectedJurisdiction = 'Nigeria (CAC)';
  bool _isLoading = false;

  void _submitEnterpriseRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

      // Send data to Firestore collection watched by your separate Admin Portal
      await FirebaseFirestore.instance.collection('enterprise_accounts').add({
        'userId': userId,
        'companyName': _companyNameController.text.trim(),
        'jurisdiction': _selectedJurisdiction,
        'regNumber': _regNumberController.text.trim(),
        'corporateEmail': _corporateEmailController.text.trim(),
        'seatCount': _seatCountController.text.trim(),
        'status': 'PendingVerification', // Triggers view in your admin portal
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enterprise registration submitted successfully! Awaiting admin review.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enterprise & Startup Onboarding"),
        backgroundColor: const Color(0xFF333697),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Register Your Organization",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333697)),
              ),
              const SizedBox(height: 8),
              const Text(
                "Unlock team licenses, centralized billing, and custom mentor matching for your engineering staff.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(labelText: "Company / Startup Name", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Please enter company name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedJurisdiction,
                decoration: const InputDecoration(labelText: "Legal Jurisdiction / Registry", border: OutlineInputBorder()),
                items: ['Nigeria (CAC)', 'United States (Delaware C-Corp)', 'United Kingdom (Companies House)', 'Other International']
                    .map((jurisdiction) => DropdownMenuItem(value: jurisdiction, child: Text(jurisdiction)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedJurisdiction = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regNumberController,
                decoration: const InputDecoration(labelText: "Registration Number (e.g., RC-123456)", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Please enter registration ID' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _corporateEmailController,
                decoration: const InputDecoration(labelText: "Corporate Domain Email", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty || !val.contains('@') ? 'Enter a valid corporate email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _seatCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Required Team Seat Licenses (e.g., 10)", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Please enter seat count' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitEnterpriseRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF333697),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Submit for Enterprise Verification", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}