import 'dart:async';
import 'package:flutter/foundation.dart';
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
  bool _isLoadingAd = false;
  bool _isCrediting = false;

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _adUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // Google Test Rewarded Ad for iOS
    }
    return 'ca-app-pub-3940256099942544/5224354917'; // Google Test Rewarded Ad for Android
  }

  @override
  void initState() {
    super.initState();
    if (_isMobilePlatform) {
      _loadRewardedAd();
    }
  }

  void _loadRewardedAd() {
    if (!_isMobilePlatform || _isLoadingAd) return;
    _isLoadingAd = true;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _rewardedAd = ad;
            _isAdLoaded = true;
            _isLoadingAd = false;
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint(
            "RewardedAd failed to load ($error). Will use sponsored video fallback.",
          );
          if (!mounted) return;
          setState(() {
            _isAdLoaded = false;
            _isLoadingAd = false;
            _rewardedAd = null;
          });
        },
      ),
    );
  }

  // --- UNIVERSAL TAP HANDLER ---
  void _handleWatchPressed() {
    if (_isMobilePlatform && _isAdLoaded && _rewardedAd != null) {
      // Mobile AdMob Ready: Trigger native AdMob ad
      _showMobileRewardedAd();
    } else {
      // Web, Desktop, or Mobile Fallback: Sponsored Video Player
      _showVideoAdDialog(context);
    }
  }

  void _showMobileRewardedAd() {
    if (_rewardedAd == null) {
      _showVideoAdDialog(context);
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint(
          "RewardedAd failed to show: $error. Falling back to video ad.",
        );
        ad.dispose();
        _loadRewardedAd();
        if (mounted) {
          _showVideoAdDialog(context);
        }
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _grantWalletMinutesAndExit(
          60.0,
          "Ad completed! +1 Hour (60 mins) added to study wallet.",
        );
      },
    );

    _rewardedAd = null;
    _isAdLoaded = false;
  }

  // 🌐 / 📱 FORCED-WATCH SPONSORED VIDEO PLAYER DIALOG
  void _showVideoAdDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SponsoredVideoPlayerWidget(
        onRewarded: () {
          _grantWalletMinutesAndExit(
            60.0,
            "Sponsored video completed! +1 Hour (60 mins) added to study wallet.",
          );
        },
      ),
    );
  }

  // --- SAFE FIRESTORE WALLET TRANSACTION ENGINE ---
  Future<void> _grantWalletMinutesAndExit(
    double minutesToAdd,
    String message,
  ) async {
    if (_isCrediting) return;
    setState(() => _isCrediting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        final snapshot = await userRef.get();
        double currentMinutes = 0.0;
        double currentUSD = 0.0;
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          currentMinutes = (data['walletMinutes'] ?? 0.0).toDouble();
          currentUSD = (data['walletBalanceUSD'] ?? 0.0).toDouble();
        }

        await userRef.set({
          'walletMinutes': currentMinutes + minutesToAdd,
          'walletBalanceUSD': currentUSD + 1.00,
          'lastAdWatchedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to credit wallet: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCrediting = false);
    }
  }

  @override
  void dispose() {
    if (_isMobilePlatform) {
      _rewardedAd?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool canPress = !_isCrediting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock Study Time'),
        backgroundColor: const Color(0xFF333697),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF333697).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_collection_rounded,
                  size: 80,
                  color: Color(0xFF333697),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Watch Ads to Build Your Study Wallet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Support free technical education. Watch short rewarded sponsor videos to unlock 1-hour study passes (60 minutes) for live tutoring and mentor sessions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF333697).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF333697).withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, color: Colors.amber, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Reward: +1 Hour (60 mins) & \$1.00 Credit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333697),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canPress ? _handleWatchPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333697),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCrediting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_fill, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              _isMobilePlatform && _isAdLoaded
                                  ? 'Watch Ad & Unlock 1 Hour'
                                  : 'Watch Sponsor Video & Unlock 1 Hour',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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

// Helper Widget for Web Browser & Mobile Fallback Local Asset Video Player
class _SponsoredVideoPlayerWidget extends StatefulWidget {
  final VoidCallback onRewarded;

  const _SponsoredVideoPlayerWidget({required this.onRewarded});

  @override
  State<_SponsoredVideoPlayerWidget> createState() =>
      _SponsoredVideoPlayerWidgetState();
}

class _SponsoredVideoPlayerWidgetState
    extends State<_SponsoredVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isCompleted = false;
  bool _hasError = false;
  int _countdownSeconds = 15;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    try {
      _controller =
          VideoPlayerController.asset('assets/videos/Payme_app_video.mp4')
            ..initialize()
                .then((_) async {
                  if (mounted) {
                    setState(() => _isInitialized = true);
                    try {
                      await _controller?.play();
                    } catch (e) {
                      debugPrint("Autoplay unmuted blocked, muting: $e");
                      await _controller?.setVolume(0.0);
                      await _controller?.play();
                    }
                  }
                })
                .catchError((error) {
                  debugPrint("Video initialization failed: $error");
                  if (mounted) {
                    setState(() => _hasError = true);
                    _startFallbackCountdown();
                  }
                });

      _controller?.addListener(_videoListener);
    } catch (e) {
      debugPrint("Video controller exception: $e");
      setState(() => _hasError = true);
      _startFallbackCountdown();
    }
  }

  void _startFallbackCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds > 1) {
          _countdownSeconds--;
        } else {
          _countdownSeconds = 0;
          _isCompleted = true;
          timer.cancel();
          widget.onRewarded();
        }
      });
    });
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;
    final value = _controller!.value;
    if (value.duration > Duration.zero &&
        value.position >= value.duration &&
        !_isCompleted) {
      setState(() => _isCompleted = true);
      widget.onRewarded();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF13132B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          const Icon(Icons.campaign, color: Colors.amber, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Sponsored Partner Video",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            tooltip: "Close",
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _hasError
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      size: 56,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Sponsored Partner Message",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isCompleted
                          ? "Thank you for watching! 1-Hour Pass Unlocked."
                          : "Unlocking your 1-Hour Study Pass in $_countdownSeconds seconds...",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (15 - _countdownSeconds) / 15,
                        minHeight: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isCompleted
                              ? Colors.greenAccent
                              : const Color(0xFFFF0000), // YouTube Red
                        ),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${15 - _countdownSeconds}s / 15s",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _isCompleted
                              ? "✓ Ready!"
                              : "$_countdownSeconds s left",
                          style: TextStyle(
                            color: _isCompleted
                                ? Colors.greenAccent
                                : Colors.amberAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : _isInitialized && _controller != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Video screen container
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black,
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio > 0
                                  ? _controller!.value.aspectRatio
                                  : 16 / 9,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                          // Audio toggle badge
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  final currentVol =
                                      _controller?.value.volume ?? 1.0;
                                  final newVol = currentVol > 0 ? 0.0 : 1.0;
                                  _controller?.setVolume(newVol);
                                  setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    (_controller?.value.volume ?? 1.0) > 0
                                        ? Icons.volume_up
                                        : Icons.volume_off,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 🔥 YouTube-style animated moving progress bar with live ticks
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _controller!,
                    builder: (context, value, child) {
                      final position = value.position;
                      final duration = value.duration;
                      final progress = duration.inMilliseconds > 0
                          ? (position.inMilliseconds / duration.inMilliseconds)
                                .clamp(0.0, 1.0)
                          : 0.0;
                      final remainingSeconds = duration > position
                          ? (duration - position).inSeconds
                          : 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // YouTube Red moving progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _isCompleted
                                    ? Colors.greenAccent
                                    : const Color(0xFFFF0000), // YouTube Red!
                              ),
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Timers and completion badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isCompleted
                                        ? Icons.check_circle
                                        : (value.isPlaying
                                              ? Icons.play_arrow
                                              : Icons.pause),
                                    size: 16,
                                    color: _isCompleted
                                        ? Colors.greenAccent
                                        : const Color(0xFFFF0000),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isCompleted
                                        ? "Finished"
                                        : "${_formatDuration(position)} / ${_formatDuration(duration)}",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _isCompleted
                                    ? "✓ Reward Ready!"
                                    : "$remainingSeconds seconds left",
                                style: TextStyle(
                                  color: _isCompleted
                                      ? Colors.greenAccent
                                      : Colors.amberAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              )
            : const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.greenAccent),
                ),
              ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: _isCompleted
                  ? Colors.greenAccent.withValues(alpha: 0.2)
                  : Colors.white10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: _isCompleted ? Colors.greenAccent : Colors.transparent,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _isCompleted ? () => Navigator.pop(context) : null,
            icon: Icon(
              _isCompleted ? Icons.check_circle : Icons.lock_clock,
              size: 20,
              color: _isCompleted ? Colors.greenAccent : Colors.white38,
            ),
            label: Text(
              _isCompleted
                  ? "Claim 1-Hour Pass"
                  : "Watch completely to claim your 1-Hour Pass",
              style: TextStyle(
                color: _isCompleted ? Colors.greenAccent : Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
