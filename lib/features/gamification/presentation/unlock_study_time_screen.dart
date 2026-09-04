import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:video_player/video_player.dart';

class UnlockStudyTimeScreen extends StatefulWidget {
  const UnlockStudyTimeScreen({super.key});

  @override
  State<UnlockStudyTimeScreen> createState() => _UnlockStudyTimeScreenState();
}

class _UnlockStudyTimeScreenState extends State<UnlockStudyTimeScreen> {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isCrediting = false;

  final String _adUnitId = 'ca-app-pub-3940256099942544/5224354917'; 

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadRewardedAd();
    }
  }

  void _loadRewardedAd() {
    if (kIsWeb) return;

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

  // --- UNIVERSAL TAP HANDLER ---
  void _handleWatchPressed() {
    if (kIsWeb) {
      // 🌐 WEB USER: Directly open the video player dialog (No AdMob lookup)
      _showWebVideoAdDialog(context);
    } else {
      // 📱 MOBILE USER: Trigger AdMob
      _showMobileRewardedAd();
    }
  }

  void _showMobileRewardedAd() {
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

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _grantWalletMinutesAndExit(10, "Ad completed successfully! +10 minutes added to wallet.");
      },
    );

    _rewardedAd = null;
    _isAdLoaded = false;
  }

  // 🌐 WEB FORCED-WATCH VIDEO PLAYER DIALOG
  void _showWebVideoAdDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WebVideoPlayerWidget(
        onRewarded: () {
          _grantWalletMinutesAndExit(10, "Sponsored video completed! +10 minutes added to wallet.");
        },
      ),
    );
  }

  // --- SAFE FIRESTORE WALLET TRANSACTION ENGINE ---
  Future<void> _grantWalletMinutesAndExit(double minutesToAdd, String message) async {
    if (_isCrediting) return;
    setState(() => _isCrediting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        
        final snapshot = await userRef.get();
        double currentMinutes = 0.0;
        if (snapshot.exists && snapshot.data() != null) {
          currentMinutes = (snapshot.data()!['walletMinutes'] ?? 0.0).toDouble();
        }

        await userRef.set({
          'walletMinutes': currentMinutes + minutesToAdd,
          'lastAdWatchedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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
    // On web, the button is always ready. On mobile, it depends on whether the ad loaded.
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
                  onPressed: canPress ? _handleWatchPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333697),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isCrediting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          kIsWeb ? 'Watch Sponsor Video & Earn 10 Mins' : (_isAdLoaded ? 'Watch Ad & Earn 10 Mins' : 'Loading Ad...'),
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

// Helper Widget for Web Browser Forced-Watch Video Ads
class _WebVideoPlayerWidget extends StatefulWidget {
  final VoidCallback onRewarded;

  const _WebVideoPlayerWidget({required this.onRewarded});

  @override
  State<_WebVideoPlayerWidget> createState() => _WebVideoPlayerWidgetState();
}

class _WebVideoPlayerWidgetState extends State<_WebVideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isCompleted = false;

  // Working open-source sample video stream URL for testing
  final String _sponsorVideoUrl = 'https://assets.mixkit.co/videos/preview/mixkit-software-developer-working-in-an-office-43281-large.mp4';

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(_sponsorVideoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.play();
        }
      });

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (!mounted) return;
    if (_controller.value.position >= _controller.value.duration && !_isCompleted) {
      setState(() => _isCompleted = true);
      widget.onRewarded();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text(
        "Sponsored Study Video",
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: SizedBox(
        width: 450,
        height: 280,
        child: _isInitialized
            ? Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _controller.value.duration.inMilliseconds > 0
                        ? _controller.value.position.inMilliseconds / _controller.value.duration.inMilliseconds
                        : 0.0,
                    color: Colors.greenAccent,
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCompleted
                        ? "Video completed! Unlocking minutes..."
                        : "Watch completely to unlock your minutes",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
      ),
      actions: [
        TextButton(
          onPressed: _isCompleted ? () => Navigator.pop(context) : null,
          child: Text(
            _isCompleted ? "Continue" : "Watch to Unlock",
            style: TextStyle(
              color: _isCompleted ? Colors.greenAccent : Colors.white24,
            ),
          ),
        ),
      ],
    );
  }
}