import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/welcome_screen.dart';

class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});

  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard> {
  bool _isOnline = false;
  bool _isSyncing = false;
  
  // Background stream subscription to intercept incoming mentee connection documents
  StreamSubscription<QuerySnapshot>? _incomingCallSubscription;
  bool _isShowingIncomingSheet = false; // Prevents showing duplicate popups

  @override
  void initState() {
    super.initState();
    _fetchCurrentOnlinePresence();
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel(); // Critical: Kill subscription memory leaks on dispose
    super.dispose();
  }

  Future<void> _fetchCurrentOnlinePresence() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          bool onlineState = data['isOnline'] ?? false;
          setState(() {
            _isOnline = onlineState;
          });
          // If the app boots up and the mentor was already marked online, start listening instantly
          if (onlineState) {
            _listenForIncomingCalls(uid);
          }
        }
      }
    }
  }

  // BACKGROUND INTERCEPTOR SOCKET: Listens for incoming student handshake entries
  void _listenForIncomingCalls(String mentorId) {
    _incomingCallSubscription?.cancel(); // Reset any existing stream loops

    // FIXED: Corrected structural parameter layout using 'isEqualTo'
    _incomingCallSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .where('mentorId', isEqualTo: mentorId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && !_isShowingIncomingSheet && _isOnline) {
        final sessionDoc = snapshot.docs.first;
        _showIncomingCallSheet(sessionDoc);
      }
    });
  }

  // DYNAMIC BOTTOM SHEET DIALOG LAYER (The Handshake Viewport)
  void _showIncomingCallSheet(DocumentSnapshot sessionDoc) {
    if (!mounted) return;
    setState(() => _isShowingIncomingSheet = true);

    final sessionData = sessionDoc.data() as Map<String, dynamic>;
    final menteeName = sessionData['menteeName'] ?? 'Anonymous Student';
    final problemTopic = sessionData['topic'] ?? 'General Engineering Question';
    const mentorAccentColor = Color(0xFF00796B);

    showModalBottomSheet(
      context: context,
      isDismissible: false, // Force active input; mentor must click Accept or Decline explicitly
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: mentorAccentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt, color: mentorAccentColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Live Request Handshake",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  "Student: $menteeName",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                const Text("Problem Topic Description:", style: TextStyle(fontSize: 13, color: Colors.grey)),
                Text(
                  "\"$problemTopic\"",
                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.blueGrey),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // DECLINE BUTTON (Closes document channel and updates layout status)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await sessionDoc.reference.update({'status': 'declined'});
                          setState(() => _isShowingIncomingSheet = false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Decline", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ACCEPT BUTTON (Updates status field to move both users to live learning state)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await sessionDoc.reference.update({
                            'status': 'accepted',
                            'connectedAt': FieldValue.serverTimestamp(),
                          });
                          setState(() => _isShowingIncomingSheet = false);
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(backgroundColor: mentorAccentColor, content: Text("Handshake complete! Transitioning to live workspace stream...")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mentorAccentColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Accept & Begin", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _syncOnlinePresencePool(bool goOnline) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isOnline = goOnline;
      _isSyncing = true;
    });

    final batch = FirebaseFirestore.instance.batch();
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final poolDocRef = FirebaseFirestore.instance.collection('available_mentors').doc(uid);

    if (goOnline) {
      final profileSnapshot = await userDocRef.get();
      final profileData = profileSnapshot.data() ?? {};

      batch.update(userDocRef, {'isOnline': true});
      batch.set(poolDocRef, {
        'mentorId': uid,
        'expertiseTag': profileData['expertiseTag'] ?? 'Expert Developer',
        'bio': profileData['bio'] ?? '',
        'connectionRatePerMin': profileData['connectionRatePerMin'] ?? 0.20,
        'linkedinUrl': profileData['linkedinUrl'] ?? '',
        'githubUrl': profileData['githubUrl'] ?? '',
        'wentLiveAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(userDocRef, {'isOnline': false});
      batch.delete(poolDocRef);
      _incomingCallSubscription?.cancel(); // Terminate call monitoring background socket when going offline
    }

    try {
      await batch.commit();
      
      // Toggle listening logic based on state position changes
      if (goOnline) {
        _listenForIncomingCalls(uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: goOnline ? const Color(0xFF00796B) : Colors.blueGrey,
            content: Text(goOnline ? "Presence Sync Active: You are visible to students!" : "Offline status propagated across the pool."),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isOnline = !goOnline);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Sync Failed: $e")),
        );
      }
    } finally {
      // FIXED: Swapped 'finaly' typo out for exact standard keyword spelling
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    const mentorAccentColor = Color(0xFF00796B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Workspace'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              if (_isOnline) {
                await _syncOnlinePresencePool(false);
              }
              await FirebaseAuth.instance.signOut();
              
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid != null
            ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
            : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: mentorAccentColor));
          }

          double mentorEarningsUSD = 0.00;
          double connectionRatePerMin = 0.20;
          String expertiseTag = "Systems Engineer";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data();
            if (data != null) {
              mentorEarningsUSD = (data['mentorEarningsUSD'] ?? 0.0).toDouble();
              connectionRatePerMin = (data['connectionRatePerMin'] ?? 0.20).toDouble();
              expertiseTag = data['expertiseTag'] ?? 'Expert Developer';
            }
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _isOnline 
                          ? mentorAccentColor.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isOnline ? mentorAccentColor : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _isSyncing
                                ? const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: mentorAccentColor),
                                  )
                                : Icon(
                                    Icons.circle,
                                    color: _isOnline ? mentorAccentColor : Colors.grey,
                                    size: 14,
                                  ),
                            const SizedBox(width: 12),
                            Text(
                              _isOnline ? "Live Pool Discovery: Active" : "Status: Hidden (Offline)",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _isOnline ? mentorAccentColor : Colors.grey.shade700),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isOnline,
                          activeThumbColor: mentorAccentColor,
                          activeTrackColor: mentorAccentColor.withValues(alpha: 0.3),
                          onChanged: _isSyncing ? null : _syncOnlinePresencePool,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      _mentorStatItem("Redeemable Wallet", "\$${mentorEarningsUSD.toStringAsFixed(2)}", Colors.green),
                      const SizedBox(width: 16),
                      _mentorStatItem("Assigned Rate", "\$${connectionRatePerMin.toStringAsFixed(2)}/min", mentorAccentColor),
                    ],
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    "Session Engine Management",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Verified Domain: $expertiseTag",
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "When visible, students searching the network can request a direct session payload handshake.",
                          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mentorStatItem(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}