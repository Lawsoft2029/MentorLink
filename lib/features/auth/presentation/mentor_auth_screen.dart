import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../mentor/presentation/mentor_registration_screen.dart';
import '../../mentor/presentation/mentor_dashboard.dart';

class MentorAuthScreen extends StatefulWidget {
  const MentorAuthScreen({super.key});

  @override
  State<MentorAuthScreen> createState() => _MentorAuthScreenState();
}

class _MentorAuthScreenState extends State<MentorAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isSignUp = false; // Toggles between Login and Registration mode
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // CORE AUTHENTICATION ENGINE & INTEL ROUTING PATHWAY
  Future<void> _handleAuthentication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    try {
      UserCredential userCredential;
      
      if (_isSignUp) {
        // 1. Create brand new authentication record credentials
        userCredential = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Initialize minimal default profile record document mapping
        await firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': _emailController.text.trim(),
          'role': 'mentor_pending', // Intermediate structural tag state
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          // Send new signups directly to fill out verification forms
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MentorRegistrationScreen()),
          );
        }
      } else {
        // 1. Attempt login credential authorization validation
        userCredential = await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Inspect database flag metrics to trace historical vetting data maps
        final userDoc = await firestore.collection('users').doc(userCredential.user!.uid).get();

        if (mounted) {
          if (userDoc.exists && userDoc.data()?['role'] == 'mentor') {
            // Vetted expert profile exists -> route directly to dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MentorDashboard()),
            );
          } else {
            // Missing registration details -> redirect to vetting inputs
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MentorRegistrationScreen()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(e.message ?? "Authentication process failed."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const mentorAccentColor = Color(0xFF00796B); // Professional Mentor Teal

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: mentorAccentColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Icon(Icons.gavel_rounded, size: 50, color: mentorAccentColor),
                    const SizedBox(height: 24),
                    Text(
                      _isSignUp ? "Create Expert Account" : "Welcome Back, Chief",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: mentorAccentColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSignUp 
                          ? "Register to begin verifying your professional experience portfolio credentials." 
                          : "Log in to activate your presence discovery engine and accept requests.",
                      style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 40),

                    // --- EMAIL INPUT ---
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Professional Email Address",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        prefixIcon: const Icon(Icons.email_outlined, color: mentorAccentColor),
                      ),
                      validator: (value) => (value == null || !value.contains('@')) ? "Enter a valid email address" : null,
                    ),
                    const SizedBox(height: 20),

                    // --- PASSWORD INPUT ---
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Secure Access Password",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        prefixIcon: const Icon(Icons.lock_outline, color: mentorAccentColor),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 6) ? "Password must contain at least 6 characters" : null,
                    ),
                    const SizedBox(height: 32),

                    // --- SUBMIT ACTION ENTRY PORTAL ---
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _handleAuthentication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mentorAccentColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text(
                          _isSignUp ? "Sign Up & Start Vetting" : "Authorize & Sign In",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- SWITCH REGISTRATION MODE LINK BUTTON ---
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp ? "Already a verified member? Log In" : "New to the platform? Apply to Mentor",
                          style: const TextStyle(color: mentorAccentColor, fontWeight: FontWeight.w600, fontSize: 14),
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