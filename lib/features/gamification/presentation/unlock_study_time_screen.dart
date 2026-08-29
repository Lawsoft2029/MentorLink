import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Only import google_mobile_ads conditionally or standardly if targeting mobile
import 'package:google_mobile_ads/google_mobile_ads.dart';

class UnlockStudyTimeScreen extends StatefulWidget {
  const UnlockStudyTimeScreen({super.key});

  @override
  State<UnlockStudyTimeScreen> createState() => _UnlockStudyTimeScreenState();
}

class _UnlockStudyTimeScreenState extends State<UnlockStudyTimeScreen> {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isCrediting = false;

  // Google's official test ad unit ID for development
  final String _adUnitId = 'ca-app-pub-3940256099942544/5224354917'; 

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadRewardedAd();
    }
  }

  void _loadRewardedAd() {
    if (kIsWeb) return; // AdMob doesn't run on Web

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          setState(() {
            _rewardedAd = ad;
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          setState(() => _isAdLoaded = false);
          _rewardedAd = null;
        },
      ),
    );
  }

  void _showRewardedAd() {
    // 🌐 WEB FALLBACK: Since AdMob isn't supported on web, simulate a verification timer or test pass for web users
    if (kIsWeb) {
      _grantWalletMinutesAndExit(10, "Web Simulation: Ad completed! +10 minutes added to wallet.");
      return;
    }

    if (!_isAdLoaded || _rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad is still loading. Please try again in a moment.')),
      );
      _loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _loadRewardedAd();
      },
    );

    // 📱 MOBILE REAL AD: User only gets rewarded if Google confirms they watched it!
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        // Boss Rule: 1 completed ad adds precise study minutes to the wallet
        _grantWalletMinutesAndExit(10, "Ad completed successfully! +10 minutes added to wallet.");
      },
    );

    _rewardedAd = null;
    _isAdLoaded = false;
  }

  // --- FIRESTORE WALLET TRANSACTION ENGINE ---
  Future<void> _grantWalletMinutesAndExit(double minutesToAdd, String message) async {
    if (_isCrediting) return;
    setState(() => _isCrediting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(userRef);
          double currentMinutes = 0.0;
          if (snapshot.exists && snapshot.data() != null) {
            currentMinutes = (snapshot.data()!['walletMinutes'] ?? 0.0).toDouble();
          }

          transaction.set(userRef, {
            'walletMinutes': currentMinutes + minutesToAdd,
            'lastAdWatchedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to credit wallet: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isCrediting = false);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _rewardedAd?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool canPress = (kIsWeb || _isAdLoaded) && !_isCrediting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock Study Time'),
        backgroundColor: const Color(0xFF333697),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.video_collection_rounded, size: 80, color: Color(0xFF333697)),
              const SizedBox(height: 24),
              const Text(
                'Watch Ads to Build Your Study Wallet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Support free technical education. Watch rewarded video ads to pile up minutes in your wallet for live tutor sessions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canPress ? _showRewardedAd : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333697),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isCrediting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          kIsWeb ? 'Watch Ad & Earn 10 Mins' : (_isAdLoaded ? 'Watch Ad & Earn 10 Mins' : 'Loading Ad...'),
                          style: const TextStyle(fontSize: 16, color: Colors.white),
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