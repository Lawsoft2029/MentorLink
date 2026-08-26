import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
      _grantRewardAndExit("Web Simulation: Ad completed successfully! +1 Hour unlocked.");
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
        _grantRewardAndExit("Ad completed successfully! +1 Hour unlocked.");
      },
    );

    _rewardedAd = null;
    _isAdLoaded = false;
  }

  void _grantRewardAndExit(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
    // Return the earned duration so the calling screen can persist the unlock.
    Navigator.pop(context, const Duration(hours: 1));
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
    // On web, we immediately allow clicking since it falls back to a simulated reward flow.
    // On mobile, it requires the ad to load first.
    bool canPress = kIsWeb || _isAdLoaded;

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
                'Watch an Ad to Earn a 1-Hour Pass',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Support free technical education. Watch a short rewarded video ad to instantly credit 1 hour of classroom time.',
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
                  child: Text(
                    kIsWeb ? 'Watch Ad & Unlock 1 Hour' : (_isAdLoaded ? 'Watch Ad & Unlock 1 Hour' : 'Loading Ad...'),
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