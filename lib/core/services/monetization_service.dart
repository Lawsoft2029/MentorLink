import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class MonetizationService {
  static final MonetizationService instance = MonetizationService._();
  MonetizationService._();

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  // Initialize or load test ads
  void loadRewardedAd() {
    if (kIsWeb) return; // Web uses simulation mode
    if (_isAdLoading) return;
    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Google Test Ad ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _isAdLoading = false;
        },
      ),
    );
  }

  // Trigger Ad (or simulate instantly on web/pitch mode)
  Future<void> watchAdForReward({
    required Function(double addedMinutes) onRewarded,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!kIsWeb && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadRewardedAd(); // Preload next ad
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          loadRewardedAd();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
          await _creditUserWallet(user.uid, 15.0); // Reward 15 minutes
          onRewarded(15.0);
        },
      );
      _rewardedAd = null;
    } else {
      // --- PITCH / WEB SIMULATION MODE ---
      // Instantly credits wallet on web or if ad isn't loaded yet for smooth demo flow
      await Future.delayed(const Duration(milliseconds: 500));
      await _creditUserWallet(user.uid, 15.0);
      onRewarded(15.0);
    }
  }

  // Helper to update Firestore wallet balance
  Future<void> _creditUserWallet(String uid, double minutesToAdd) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snapshot = await docRef.get();

    double currentMinutes = 0.0;
    if (snapshot.exists && snapshot.data()!.containsKey('walletMinutes')) {
      currentMinutes = (snapshot.data()!['walletMinutes'] as num).toDouble();
    }

    await docRef.set({
      'walletMinutes': currentMinutes + minutesToAdd,
    }, SetOptions(merge: true));
  }
}
