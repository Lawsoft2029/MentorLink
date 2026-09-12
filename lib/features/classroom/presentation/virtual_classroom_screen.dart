// ignore_for_file: prefer_final_fields, curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mentorlinks_app_project/features/gamification/presentation/unlock_study_time_screen.dart';

class VirtualClassroomScreen extends StatefulWidget {
  final String roomName;
  final String participantName;
  final String sessionId;
  final String role; // 'mentee' or 'mentor'
  final double ratePerMinute =
      0.10; // $0.10 or 1 minute of wallet per real minute

  const VirtualClassroomScreen({
    super.key,
    required this.roomName,
    required this.participantName,
    required this.sessionId,
    required this.role,
  });

  @override
  State<VirtualClassroomScreen> createState() => _VirtualClassroomScreenState();
}

class _VirtualClassroomScreenState extends State<VirtualClassroomScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isScreenSharing = false;
  bool _isPaused = false;
  bool _isModalShowing = false;

  int _seconds = 0;
  double _totalCost = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialBalance();
    });
  }

  Future<void> _checkInitialBalance() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (widget.role == 'mentee') {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists && mounted) {
          final data = doc.data() as Map<String, dynamic>;
          double walletMinutes = (data['walletMinutes'] ?? 0.0).toDouble();
          double walletBalanceUSD = (data['walletBalanceUSD'] ?? 0.0)
              .toDouble();

          if (walletMinutes <= 0.0 && walletBalanceUSD < widget.ratePerMinute) {
            _showStudyWalletEmptyModal(context);
            return;
          }
        }
      } catch (e) {
        debugPrint("Initial wallet balance check error: $e");
      }
    }
    _startSessionTimer();
  }

  // --- LIVE PER-MINUTE WALLET DEDUCTION TIMER ---
  void _startSessionTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isPaused) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Only mentees consume wallet minutes; mentors accrue earnings
      if (widget.role == 'mentee') {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

        try {
          final docSnapshot = await userDoc.get();
          if (docSnapshot.exists) {
            final data = docSnapshot.data() as Map<String, dynamic>;
            double walletMinutes = (data['walletMinutes'] ?? 0.0).toDouble();
            double walletBalanceUSD = (data['walletBalanceUSD'] ?? 0.0)
                .toDouble();

            // Prompt ad unlock if wallet hits zero instead of auto-closing session
            if (walletMinutes <= 0.0 &&
                walletBalanceUSD < widget.ratePerMinute) {
              _timer?.cancel();
              if (mounted) {
                _showStudyWalletEmptyModal(context);
              }
              return;
            }

            if (mounted) {
              setState(() {
                _seconds++;
                _totalCost += (widget.ratePerMinute / 60);
              });
            }

            // Deduct fractional minutes from wallet per second
            await userDoc.update({
              'walletMinutes': FieldValue.increment(-1 / 60),
              'totalMinutesLearned': FieldValue.increment(1 / 60),
            });
          }
        } catch (e) {
          debugPrint("Wallet deduction sync failed: $e");
        }
      } else {
        if (mounted) {
          setState(() {
            _seconds++;
          });
        }
      }
    });
  }

  // --- STUDY WALLET EMPTY: CROSS-PLATFORM AD-REWARD MODAL ---
  void _showStudyWalletEmptyModal(BuildContext context) {
    if (_isModalShowing || !mounted) return;
    _isModalShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 48,
                  color: Colors.amberAccent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Study Wallet Empty! 🛑",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "You don't have enough balance to start or continue this live class session. Watch a short sponsored ad to unlock 1 hour of study time (+60 mins) and \$1.00 credit!",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333697),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              icon: const Icon(
                Icons.play_circle_fill,
                color: Colors.amberAccent,
                size: 24,
              ),
              label: const Text(
                "Watch Ad & Unlock Class (+60 Mins)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                Navigator.pop(modalContext);
                _isModalShowing = false;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UnlockStudyTimeScreen(),
                  ),
                );
                if (mounted) {
                  _recheckWalletAndResume();
                }
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(modalContext);
                _isModalShowing = false;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                "Return to Dashboard",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _isModalShowing = false;
    });
  }

  Future<void> _recheckWalletAndResume() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        double walletMinutes = (data['walletMinutes'] ?? 0.0).toDouble();
        double walletBalanceUSD = (data['walletBalanceUSD'] ?? 0.0).toDouble();

        if (walletMinutes > 0.0 || walletBalanceUSD >= widget.ratePerMinute) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                "Study pass active! Starting live class session...",
              ),
            ),
          );
          setState(() {
            _isPaused = false;
          });
          _startSessionTimer();
        } else {
          // Still empty (e.g. user backed out without watching ad)
          _showStudyWalletEmptyModal(context);
        }
      }
    } catch (e) {
      debugPrint("Error re-checking wallet: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- BOSS RULE: EXACT TIME SETTLEMENT & TUTOR PAYOUT ON EXIT ---
  void _confirmAndEndSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("End Session", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to end this class session? The tutor will be paid for the exact minutes spent.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () async {
              _timer?.cancel();

              double exactMinutesSpent = _seconds / 60.0;
              double tutorEarnings = exactMinutesSpent * widget.ratePerMinute;

              try {
                // Fetch session record to locate mentor ID
                final sessionDoc = await FirebaseFirestore.instance
                    .collection('sessions')
                    .doc(widget.sessionId)
                    .get();

                final sessionData = sessionDoc.data() ?? {};
                final mentorUid =
                    sessionData['mentorId'] ?? sessionData['mentorUid'];

                final batch = FirebaseFirestore.instance.batch();

                // 1. Update session status & final duration
                final sessionRef = FirebaseFirestore.instance
                    .collection('sessions')
                    .doc(widget.sessionId);
                batch.set(sessionRef, {
                  'minutesSpent': exactMinutesSpent,
                  'tutorEarnedUSD': tutorEarnings,
                  'endedAt': FieldValue.serverTimestamp(),
                  'status': 'Completed',
                }, SetOptions(merge: true));

                // 2. Pay the mentor proportionally
                if (mentorUid != null) {
                  final mentorRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(mentorUid);
                  batch.update(mentorRef, {
                    'mentorEarningsUSD': FieldValue.increment(tutorEarnings),
                  });
                }

                await batch.commit();

                if (!mounted) return;
                Navigator.pop(context); // Close dialog
                Navigator.of(
                  context,
                ).popUntil((route) => route.isFirst); // Exit classroom
              } catch (e) {
                debugPrint("Error settling classroom payment: $e");
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text(
              "Yes",
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Classroom: ${widget.roomName}",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.security, size: 20),
            tooltip: "Encrypted Room",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("End-to-end encrypted mentoring room active."),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Video Feed Simulation Grid
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333697),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      widget.participantName.isNotEmpty
                          ? widget.participantName[0].toUpperCase()
                          : "M",
                      style: const TextStyle(
                        fontSize: 50,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.participantName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Connected via MentorLinks Secure Video Relay",
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  "Accrued Cost: \$${_totalCost.toStringAsFixed(4)}",
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Floating Self-View Simulation Box (Top Right)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white54, size: 40),
              ),
            ),
          ),

          // Bottom Control Toolbar
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mute Mic Button
                FloatingActionButton(
                  heroTag: "mute",
                  backgroundColor: _isMuted ? Colors.red : Colors.grey[800],
                  onPressed: () => setState(() => _isMuted = !_isMuted),
                  child: Icon(
                    _isMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16, width: 16),

                // Pause / Break Class Button
                FloatingActionButton(
                  heroTag: "pause_break",
                  backgroundColor: _isPaused ? Colors.green : Colors.orange,
                  onPressed: () {
                    setState(() => _isPaused = !_isPaused);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isPaused
                              ? "Class paused. Billing halted."
                              : "Class resumed.",
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(
                    _isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),

                // Toggle Video Button
                FloatingActionButton(
                  heroTag: "video",
                  backgroundColor: _isVideoOff ? Colors.red : Colors.grey[800],
                  onPressed: () => setState(() => _isVideoOff = !_isVideoOff),
                  child: Icon(
                    _isVideoOff ? Icons.videocam_off : Icons.videocam,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),

                // Screen Share Button
                FloatingActionButton(
                  heroTag: "screen",
                  backgroundColor: _isScreenSharing
                      ? Colors.teal
                      : Colors.grey[800],
                  onPressed: () =>
                      setState(() => _isScreenSharing = !_isScreenSharing),
                  child: Icon(
                    _isScreenSharing
                        ? Icons.screen_share
                        : Icons.stop_screen_share,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),

                // End Call Button (Triggers Payout Settlement)
                FloatingActionButton(
                  heroTag: "end_call",
                  backgroundColor: Colors.redAccent,
                  onPressed: _confirmAndEndSession,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
