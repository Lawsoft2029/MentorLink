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
  bool _isOnline = false; // Internal tracking state for the toggle switch
  bool _isSyncing = false; // Safe lock to prevent rapid spam clicking

  @override
  void initState() {
    super.initState();
    _fetchCurrentOnlinePresence();
  }

  // Double check actual database state on boot so UI switch state never lies
  Future<void> _fetchCurrentOnlinePresence() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _isOnline = data['isOnline'] ?? false;
          });
        }
      }
    }
  }

  // THE GLOBAL SYNC POOL ENGINE: Toggles presence flags across target endpoints
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
      // 1. Fetch mentor's current profile details to populate the discovery card
      final profileSnapshot = await userDocRef.get();
      final profileData = profileSnapshot.data() ?? {};

      // 2. Queue Update: Set local user document flags
      batch.update(userDocRef, {'isOnline': true});

      // 3. Queue Set: Inject profile into global discovery pool for Mentees
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
      // 1. Queue Update: Set local user document offline
      batch.update(userDocRef, {'isOnline': false});

      // 2. Queue Delete: Obliterate record from active matching pool completely
      batch.delete(poolDocRef);
    }

    try {
      // Commit the database edits atomically in a single trip
      await batch.commit();

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
      // Rollback UI switch position if connection drops out mid-write
      setState(() => _isOnline = !goOnline);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Sync Failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    const mentorAccentColor = Color(0xFF00796B); // Unified clean teal theme

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
              // Graceful Exit Guard: Erase mentor presence before token invalidation
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
            // FIXED: Removed the redundant unnecessary cast syntax layer here
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
                  // --- ONLINE/OFFLINE PRESENCE SYNC CARD ---
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

                  // --- FINANCIAL ANALYTICS BANNER ---
                  Row(
                    children: [
                      _mentorStatItem("Redeemable Wallet", "\$${mentorEarningsUSD.toStringAsFixed(2)}", Colors.green),
                      const SizedBox(width: 16),
                      _mentorStatItem("Assigned Rate", "\$${connectionRatePerMin.toStringAsFixed(2)}/min", mentorAccentColor),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- REAL-TIME CALL HANDLING CONTROLLER ---
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
            // FIXED: Swapped undefined .black helper property for exact .w900 token
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}