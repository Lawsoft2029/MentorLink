// ignore_for_file: prefer_final_fields, curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VirtualClassroomScreen extends StatefulWidget {
  final String roomName;
  final String participantName;
  final String sessionId;
  final String role; // 'mentee' or 'mentor'
  final double ratePerMinute = 0.10; // $0.10 or 1 minute of wallet per real minute

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

  int _seconds = 0;
  double _totalCost = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSessionTimer();
  }

  // --- BOSS RULE: LIVE PER-MINUTE WALLET DEDUCTION TIMER ---
  void _startSessionTimer() {
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

            // Auto-close if wallet hits zero
            if (walletMinutes <= 0.0) {
              _timer?.cancel();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text(
                      "Session closed: Your study wallet is empty! Watch more ads to continue.",
                    ),
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
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
                final mentorUid = sessionData['mentorId'] ?? sessionData['mentorUid'];

                final batch = FirebaseFirestore.instance.batch();

                // 1. Update session status & final duration
                final sessionRef = FirebaseFirestore.instance
                    .collection('sessions')
                    .doc(widget.sessionId);
                batch.set(
                  sessionRef,
                  {
                    'minutesSpent': exactMinutesSpent,
                    'tutorEarnedUSD': tutorEarnings,
                    'endedAt': FieldValue.serverTimestamp(),
                    'status': 'Completed',
                  },
                  SetOptions(merge: true),
                );

                // 2. Pay the mentor proportionally
                if (mentorUid != null) {
                  final mentorRef =
                      FirebaseFirestore.instance.collection('users').doc(mentorUid);
                  batch.update(mentorRef, {
                    'mentorEarningsUSD': FieldValue.increment(tutorEarnings),
                  });
                }

                await batch.commit();

                if (!mounted) return;
                Navigator.pop(context); // Close dialog
                Navigator.of(context).popUntil((route) => route.isFirst); // Exit classroom
              } catch (e) {
                debugPrint("Error settling classroom payment: $e");
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Yes", style: TextStyle(color: Colors.greenAccent)),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Classroom: ${widget.roomName}"),
            Text(
              "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}",
              style: const TextStyle(color: Colors.greenAccent, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("End-to-end encrypted mentoring room active.")),
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
                      color: Colors.greenAccent, fontWeight: FontWeight.bold),
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
                  backgroundColor:
                      _isScreenSharing ? Colors.teal : Colors.grey[800],
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