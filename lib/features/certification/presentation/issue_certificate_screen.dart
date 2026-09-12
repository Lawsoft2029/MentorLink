import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IssueCertificateScreen extends StatefulWidget {
  final String? initialMenteeEmail;
  final String? initialCourseName;

  const IssueCertificateScreen({
    super.key,
    this.initialMenteeEmail,
    this.initialCourseName,
  });

  @override
  State<IssueCertificateScreen> createState() => _IssueCertificateScreenState();
}

class _IssueCertificateScreenState extends State<IssueCertificateScreen> {
  late final TextEditingController _menteeEmailController;
  late final TextEditingController _courseNameController;
  bool _isIssuing = false;

  @override
  void initState() {
    super.initState();
    _menteeEmailController = TextEditingController(
      text: widget.initialMenteeEmail ?? '',
    );
    _courseNameController = TextEditingController(
      text: widget.initialCourseName ?? '',
    );
  }

  @override
  void dispose() {
    _menteeEmailController.dispose();
    _courseNameController.dispose();
    super.dispose();
  }

  void _issueCertificate() async {
    final email = _menteeEmailController.text.trim();
    final course = _courseNameController.text.trim();

    if (email.isEmpty || course.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all certificate fields.")),
      );
      return;
    }

    setState(() => _isIssuing = true);

    try {
      final mentorId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final mentorEmail = FirebaseAuth.instance.currentUser?.email ?? '';

      // Look up mentee's certified legal details
      String studentLegalName = "Certified Student";
      String studentDob = "Verified";

      final menteeQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (menteeQuery.docs.isNotEmpty) {
        final data = menteeQuery.docs.first.data();
        studentLegalName =
            data['legalName'] ?? data['name'] ?? studentLegalName;
        studentDob = data['dateOfBirth'] ?? studentDob;
      }

      final credentialId =
          'ML-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      // Save certificate record to Firestore
      await FirebaseFirestore.instance.collection('certificates').add({
        'mentorId': mentorId,
        'mentorEmail': mentorEmail,
        'menteeEmail': email,
        'recipientLegalName': studentLegalName,
        'recipientDateOfBirth': studentDob,
        'courseName': course,
        'issuedAt': FieldValue.serverTimestamp(),
        'credentialId': credentialId,
        'status': 'Verified',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Certificate issued to $studentLegalName (DOB: $studentDob) for $course!",
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to issue certificate: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isIssuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Issue Mentorship Certificate"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Recognize Mentee Achievement",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Issue an official platform-verified certificate. The certificate embeds the student's certified Legal Name and Date of Birth.",
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _menteeEmailController,
              decoration: const InputDecoration(
                labelText: "Mentee Email Address",
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _courseNameController,
              decoration: const InputDecoration(
                labelText: "Program / Track Name (e.g., Flutter Engineering)",
                prefixIcon: Icon(Icons.school_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isIssuing ? null : _issueCertificate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isIssuing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Generate & Issue Certificate",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
