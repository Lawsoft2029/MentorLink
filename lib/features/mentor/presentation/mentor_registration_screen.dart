import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mentor_dashboard.dart';

class MentorRegistrationScreen extends StatefulWidget {
  const MentorRegistrationScreen({super.key});

  @override
  State<MentorRegistrationScreen> createState() => _MentorRegistrationScreenState();
}

class _MentorRegistrationScreenState extends State<MentorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for text fields
  final _expertiseController = TextEditingController();
  final _bioController = TextEditingController();
  final _githubController = TextEditingController();
  final _linkedinController = TextEditingController();

  // State Management properties for our quality check gates
  double _chargeRatePerMin = 0.20; // Default dynamic setting
  bool _isGithubVerified = false;
  bool _isLinkedinVerified = false;
  bool _hasUploadedCert = false;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _expertiseController.dispose();
    _bioController.dispose();
    _githubController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  // Verification simulation functions
  void _verifyGitHub() {
    if (_githubController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isGithubVerified = true;
        _isLoading = false;
      });
    });
  }

  void _verifyLinkedIn() {
    if (_linkedinController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLinkedinVerified = true;
        _isLoading = false;
      });
    });
  }

  void _simulateCertUpload() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 1).abs(), () {
      setState(() {
        _hasUploadedCert = true;
        _isLoading = false;
      });
    });
  }

  // Submission pipeline targeting our Firestore architecture
  Future<void> _submitRegistrationPortfolio() async {
    if (!_formKey.currentState!.validate() || !_isGithubVerified || !_isLinkedinVerified || !_hasUploadedCert || !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("Please satisfy all 4 Quality Gate layers before submission."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'role': 'mentor',
          'expertiseTag': _expertiseController.text.trim(),
          'bio': _bioController.text.trim(),
          'githubUrl': _githubController.text.trim(),
          'linkedinUrl': _linkedinController.text.trim(),
          'connectionRatePerMin': _chargeRatePerMin,
          'mentorEarningsUSD': 0.00,
          'isApproved': true, // Auto-approved for development sandbox
          'isOnline': false,
          'submittedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MentorDashboard()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Submission Error: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Expert Vetting Portal'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Become a Verified Mentor",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "We maintain strict standards to ensure premium support. Connect your profiles and upload credentials to unlock the dashboard workspace.",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // --- FIELD 1: CORE EXPERTISE ---
                    TextFormField(
                      controller: _expertiseController,
                      decoration: InputDecoration(
                        labelText: "Primary Technical Domain / Expertise",
                        hintText: "e.g., Flutter Developer, PLC Systems Engineer",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.psychology, color: primaryColor),
                      ),
                      validator: (value) => value!.isEmpty ? "Enter your domain focus" : null,
                    ),
                    const SizedBox(height: 16),

                    // --- FIELD 2: BIO ---
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Professional Biography Summary",
                        hintText: "Briefly explain your field track record...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.assignment, color: primaryColor),
                      ),
                      validator: (value) => value!.isEmpty ? "Please write a brief background description" : null,
                    ),
                    const SizedBox(height: 24),

                    // --- LAYER 1 & 2: GITHUB & LINKEDIN PORTFOLIO GATES ---
                    const Text("Identity & Portfolio Validation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    
                    _verificationRow(
                      controller: _githubController,
                      hint: "GitHub Username or URL",
                      isVerified: _isGithubVerified,
                      onVerifyPressed: _verifyGitHub,
                      icon: Icons.code,
                    ),
                    const SizedBox(height: 12),
                    _verificationRow(
                      controller: _linkedinController,
                      hint: "LinkedIn Profile URL",
                      isVerified: _isLinkedinVerified,
                      onVerifyPressed: _verifyLinkedIn,
                      icon: Icons.business,
                    ),
                    const SizedBox(height: 24),

                    // --- LAYER 3: CERTIFICATION ARCHIVE UPLOAD ---
                    const Text("Professional Credentials", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _simulateCertUpload,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _hasUploadedCert ? Colors.greenAccent.withValues(alpha: 0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _hasUploadedCert ? Colors.green : Colors.grey.shade300, style: BorderStyle.solid),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _hasUploadedCert
                              ? [const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 8), const Text("Credential Sheet Verified (.PDF)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]
                              : [const Icon(Icons.cloud_upload, color: primaryColor), const SizedBox(width: 8), const Text("Upload Engineering/Tech Certificate")],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- LAYER 4: OPTION B PRICE RATE CONFIGURATION SLIDER ---
                    Text(
                      "Set Connection Charge Rate: \$${_chargeRatePerMin.toStringAsFixed(2)}/min",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Equivalent to \$${(_chargeRatePerMin * 60).toStringAsFixed(0)} per hour of instructional call interaction runtime.",
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                    Slider(
                      value: _chargeRatePerMin,
                      min: 0.10,
                      max: 2.00,
                      divisions: 19,
                      activeColor: primaryColor,
                      inactiveColor: Colors.grey.shade300,
                      label: "\$${_chargeRatePerMin.toStringAsFixed(2)}/min",
                      onChanged: (val) => setState(() => _chargeRatePerMin = val),
                    ),
                    const SizedBox(height: 16),

                    // --- ESCROW HANDSHAKE COMPLIANCE CHECKBOX ---
                    CheckboxListTile(
                      title: const Text("Handshake Billing Agreement", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text("I agree that billing only accumulates when both parties actively accept an established session connection document.", style: TextStyle(fontSize: 12)),
                      value: _agreedToTerms,
                      activeColor: primaryColor,
                      onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 32),

                    // --- VALIDATION SUBMIT ACTION PORTAL ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _submitRegistrationPortfolio,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Submit Professional Profile", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _verificationRow({
    required TextEditingController controller,
    required String hint,
    required bool isVerified,
    required VoidCallback onVerifyPressed,
    required IconData icon,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            enabled: !isVerified,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(icon, color: const Color(0xFF333697)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: isVerified ? null : onVerifyPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isVerified ? Colors.green : const Color(0xFF333697),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.green.shade600,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          ),
          child: isVerified ? const Icon(Icons.check) : const Text("Verify"),
        ),
      ],
    );
  }
}