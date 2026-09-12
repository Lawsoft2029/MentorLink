import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdPassUnlockScreen extends StatefulWidget {
  const AdPassUnlockScreen({super.key});

  @override
  State<AdPassUnlockScreen> createState() => _AdPassUnlockScreenState();
}

class _AdPassUnlockScreenState extends State<AdPassUnlockScreen> {
  bool _isLoading = false;

  Future<void> _simulateAdAndUnlockHour() async {
    setState(() => _isLoading = true);

    // Production note: replace this simulation with Google Mobile Ads (AdMob)
    // rewarded-ad load and show callbacks before deploying.
    // Simulating ad viewing experience with a 3-second delay:
    await Future.delayed(const Duration(seconds: 3));

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        // Increment the user's session credits by 1 hour in Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'sessionCreditsHours': FieldValue.increment(1.0),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ad completed successfully! +1 Hour unlocked."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Return back to the classroom/dashboard
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error updating credits: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Unlock Study Time"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.ondemand_video_rounded,
                size: 64,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Watch an Ad to Earn a 1-Hour Pass",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Support free technical education. Watch a short rewarded video ad to instantly credit 1 hour of ad-free classroom teaching time to your account.",
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoading ? null : _simulateAdAndUnlockHour,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "Watch Ad & Unlock 1 Hour",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
