// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/interests_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class MenteeAuthScreen extends StatefulWidget {
  const MenteeAuthScreen({super.key});

  @override
  State<MenteeAuthScreen> createState() => _MenteeAuthScreenState();
}

class _MenteeAuthScreenState extends State<MenteeAuthScreen> {
  bool isLogin = true;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      print("1. starting Google Sign-In...");
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        print("Google Sign-In cancelled by user.");
        setState(() => _isLoading = false);
        return;
      }
      print("2. Google user obtained, ${googleUser.email}");

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print("3. signing in with Firebase Auth...");
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      print("4. Firebase Auth successful, ${userCredential.user!.email}");

      // Save mentee profile to Firestore
      print("5. saving user profile to Firestore...");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'name': userCredential.user!.displayName ?? 'Mentee',
            'email': userCredential.user!.email ?? '',
            'role': 'mentee',
            'walletMinutes': 10.0,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print("6. User profile saved to Firestore successfully.");

      if (mounted) {
        print("7. Navigating to CourseSelectionScreen...");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CourseSelectionScreen(),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Google Sign-In failed: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      print("1. starting Apple Sign-In...");
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider provider = OAuthProvider('apple.com');
      final AuthCredential credential = provider.credential(
        idToken: appleCredential.identityToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'name': appleCredential.givenName ?? 'Mentee',
            'email': userCredential.user!.email ?? '',
            'role': 'mentee',
            'walletMinutes': 10.0,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CourseSelectionScreen(),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Apple Sign-In failed: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // --- FIREBASE AUTH LOGIC ---
  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        await userCredential.user?.updateDisplayName(
          _nameController.text.trim(),
        );

        // --- INITIALIZE FIRESTORE SCHEMA WITH WALLET MINUTES FOR ADS ---
        final uid = userCredential.user?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'uid': uid,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'role': 'mentee',
            'userTier': 'Freemium',
            'isPremium': false,
            'walletMinutes':
                0.0, // Tracks ad-earned minutes for per-minute class sessions
            'walletBalanceUSD': 0.0,
            'mentorEarningsUSD': 0.0,
            'connectionRatePerMin': 0.10,
            'enrolledCourses': [],
            'courseTimelines': {},
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CourseSelectionScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Authentication failed")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLogin ? "Welcome Back!" : "Create Account",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333697),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isLogin
                  ? "Login to continue your learning journey."
                  : "Join MentorLinks to find your perfect mentor.",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            if (!isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email Address",
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF333697),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isLogin ? "LOGIN" : "SIGN UP",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(child: Divider(thickness: 1, color: Colors.grey[200])),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    "Or continue with",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                Expanded(child: Divider(thickness: 1, color: Colors.grey[200])),
              ],
            ),

            const SizedBox(height: 25),

            // Replace the single Google button with these options:
            _socialButton(
              label: "Google",
              icon: Icons.g_mobiledata,
              onTap: _signInWithGoogle,
            ),
            const SizedBox(height: 15),
            // To this stricter check:
            if (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.macOS))
              _socialButton(
                label: "Apple",
                icon: Icons.apple,
                onTap: _signInWithApple,
              ),

            const SizedBox(height: 30),
            Center(
              child: TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: RichText(
                  text: TextSpan(
                    text: isLogin
                        ? "New to MentorLinks? "
                        : "Already have an account? ",
                    style: const TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(
                        text: isLogin ? "Create Account" : "Login",
                        style: const TextStyle(
                          color: Color(0xFF333697),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.black, size: 26),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[300]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
