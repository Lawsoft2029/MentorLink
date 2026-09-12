import 'package:flutter/material.dart';
import '../../../core/services/kyc_service.dart'; // Adjust path based on your folder structure

class KybScreen extends StatefulWidget {
  const KybScreen({super.key});

  @override
  State<KybScreen> createState() => _KybScreenState();
}

class _KybScreenState extends State<KybScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();

  String _selectedCountryCode = 'NG'; // Default to Nigeria (Local CAC)
  bool _isLoading = false;

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Call our mock business verification service
      bool isSuccess = await KycService.verifyBusinessEntity(
        countryCode: _selectedCountryCode,
        businessName: _businessNameController.text.trim(),
        registrationNumber: _regNumberController.text.trim(),
      );

      if (isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business Verification (KYB) Successful!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _regNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Verification (KYB)')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Verify your enterprise to unlock merchant access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Region Dropdown (Local vs Global Jurisdiction)
              DropdownButtonFormField<String>(
                initialValue: _selectedCountryCode,
                decoration: const InputDecoration(
                  labelText: 'Select Corporate Jurisdiction',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'NG',
                    child: Text('Nigeria (Local - CAC)'),
                  ),
                  DropdownMenuItem(
                    value: 'US',
                    child: Text('United States (Global - EIN)'),
                  ),
                  DropdownMenuItem(
                    value: 'UK',
                    child: Text('United Kingdom (Global - Companies House)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCountryCode = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Business Name Field
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(
                  labelText: 'Registered Business Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your business name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Registration Number Input Field
              TextFormField(
                controller: _regNumberController,
                decoration: const InputDecoration(
                  labelText: 'Registration Number (RC Number / Tax ID)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a registration number';
                  }
                  if (value.trim().length < 5) {
                    return 'Registration number must be at least 5 characters long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit Button / Loading Indicator
              ElevatedButton(
                onPressed: _isLoading ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Verify Business',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
