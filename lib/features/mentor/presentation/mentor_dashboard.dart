import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/welcome_screen.dart';
import 'mentor_registration_screen.dart'; // Import to link validation sheet action click

class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});

  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard> {
  bool _isOnline = false;
  bool _isSyncing = false;
  
  StreamSubscription<QuerySnapshot>? _incomingCallSubscription;
  bool _isShowingIncomingSheet = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentOnlinePresence();
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
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
          if (onlineState) {
            _listenForIncomingCalls(uid);
          }
        }
      }
    }
  }

  void _listenForIncomingCalls(String mentorId) {
    _incomingCallSubscription?.cancel();
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

  void _showIncomingCallSheet(DocumentSnapshot sessionDoc) {
    if (!mounted) return;
    setState(() => _isShowingIncomingSheet = true);

    final sessionData = sessionDoc.data() as Map<String, dynamic>;
    final menteeName = sessionData['menteeName'] ?? 'Anonymous Student';
    final problemTopic = sessionData['topic'] ?? 'General Engineering Question';
    const mentorAccentColor = Color(0xFF00796B);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
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
                      decoration: BoxDecoration(color: mentorAccentColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.bolt, color: mentorAccentColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text("Live Request Handshake", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 18),
                Text("Student: $menteeName", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text("\"$problemTopic\"", style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await sessionDoc.reference.update({'status': 'declined'});
                          setState(() => _isShowingIncomingSheet = false);
                        },
                        child: const Text("Decline"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await sessionDoc.reference.update({
                            'status': 'accepted',
                            'connectedAt': FieldValue.serverTimestamp(),
                          });
                          setState(() => _isShowingIncomingSheet = false);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: mentorAccentColor),
                        child: const Text("Accept & Begin", style: TextStyle(color: Colors.white)),
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
        'connectionRatePerMin': profileData['connectionRatePerMin'] ?? 0.20,
        'wentLiveAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(userDocRef, {'isOnline': false});
      batch.delete(poolDocRef);
      _incomingCallSubscription?.cancel();
    }

    try {
      await batch.commit();
      if (goOnline) _listenForIncomingCalls(uid);
    } catch (e) {
      setState(() => _isOnline = !goOnline);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    const mentorAccentColor = Color(0xFF00796B);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Mentor Workspace'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              if (_isOnline) await _syncOnlinePresencePool(false);
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
        stream: uid != null ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots() : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: mentorAccentColor));
          }

          double mentorEarningsUSD = 0.00;
          double connectionRatePerMin = 0.20;
          String expertiseTag = "Systems Engineer";
          bool isApproved = false; // Internal validation tracking metric

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data();
            if (data != null) {
              mentorEarningsUSD = (data['mentorEarningsUSD'] ?? 0.0).toDouble();
              connectionRatePerMin = (data['connectionRatePerMin'] ?? 0.20).toDouble();
              expertiseTag = data['expertiseTag'] ?? 'Pending Verification';
              isApproved = data['isApproved'] ?? false;
            }
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- DYNAMIC SECURITY VETTING NOTIFICATION BANNER ---
                  if (!isApproved) ...[
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MentorRegistrationScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade700, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.gavel_rounded, color: Colors.amber.shade900, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Verification Mandatory",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Tap here to link your GitHub, LinkedIn, and certificates to unlock discovery features.",
                                    style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, color: Colors.amber.shade900, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // --- ONLINE/OFFLINE SWITCH CONTROL CARD ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _isOnline ? mentorAccentColor.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isOnline ? mentorAccentColor : Colors.grey.shade300, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.circle, color: _isOnline ? mentorAccentColor : Colors.grey, size: 14),
                            const SizedBox(width: 12),
                            Text(
                              _isOnline ? "Live Pool Discovery: Active" : "Status: Hidden (Offline)",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isOnline ? mentorAccentColor : Colors.grey.shade700),
                            ),
                          ],
                        ),
                        Switch(
                          // FORCE SECURITY CLOSURE: Switch stays disabled until account approval occurs
                          value: _isOnline,
                          activeThumbColor: mentorAccentColor,
                          onChanged: (isApproved && !_isSyncing) ? _syncOnlinePresencePool : null,
                        ),
                      ],
                    ),
                  ),
                  if (!isApproved)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0, left: 4),
                      child: Text(
                        "*Account status must be verified before moving online.",
                        style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontStyle: FontStyle.italic),
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

                  const Text("Session Engine Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Verified Domain: $expertiseTag", style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey, fontSize: 15)),
                        const SizedBox(height: 8),
                        const Text("When visible, students searching the network can request a direct session payload handshake.", style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4)),
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
        decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
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