import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ensure this import matches your interests_screen.dart file name
import 'package:mentorlinks_app_project/features/auth/presentation/interests_screen.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // --- FIREBASE AUTH LOGIC ---
  Future<void> _handleAuth() async {
    // Basic validation for offline development
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
      }

      if (mounted) {
        // STEP 3 OF YOUR FLOW: Navigate to Interests/Course Selection
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CourseSelectionScreen(), // Matches your flow plan
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

            _socialButton(
              label: "Continue with Google",
              icon: Icons.g_mobiledata,
              onTap: () {}, 
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
