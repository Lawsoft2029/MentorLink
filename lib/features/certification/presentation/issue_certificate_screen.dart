import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IssueCertificateScreen extends StatefulWidget {
  const IssueCertificateScreen({super.key});

  @override
  State<IssueCertificateScreen> createState() => _IssueCertificateScreenState();
}

class _IssueCertificateScreenState extends State<IssueCertificateScreen> {
  final TextEditingController _menteeEmailController = TextEditingController();
  final TextEditingController _courseNameController = TextEditingController();
  bool _isIssuing = false;

  void _issueCertificate() async {
    if (_menteeEmailController.text.trim().isEmpty || _courseNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all certificate fields.")),
      );
      return;
    }

    setState(() => _isIssuing = true);

    try {
      final mentorId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      // Save certificate record to Firestore
      await FirebaseFirestore.instance.collection('certificates').add({
        'mentorId': mentorId,
        'menteeEmail': _menteeEmailController.text.trim(),
        'courseName': _courseNameController.text.trim(),
        'issuedAt': FieldValue.serverTimestamp(),
        'credentialId': 'ML-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Certificate issued successfully and sent to mentee!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to issue certificate: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isIssuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Issue Mentorship Certificate"),
        backgroundColor: const Color(0xFF333697),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Recognize Mentee Achievement",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333697)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Issue an official platform-verified certificate of completion for your mentee.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _menteeEmailController,
              decoration: const InputDecoration(
                labelText: "Mentee Email Address",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _courseNameController,
              decoration: const InputDecoration(
                labelText: "Program / Skill Track Name (e.g., Flutter Engineering)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isIssuing ? null : _issueCertificate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isIssuing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Generate & Issue Certificate",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}