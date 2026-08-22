import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/welcome_screen.dart';
import 'mentor_registration_screen.dart';
import 'live_session_screen.dart';
import 'withdraw_funds_dialog.dart';

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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
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
          if (snapshot.docs.isNotEmpty &&
              !_isShowingIncomingSheet &&
              _isOnline) {
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
                      child: const Icon(
                        Icons.bolt,
                        color: mentorAccentColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Live Request Handshake",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  "Student: $menteeName",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "\"$problemTopic\"",
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await sessionDoc.reference.update({
                            'status': 'declined',
                          });
                          setState(() => _isShowingIncomingSheet = false);
                        },
                        child: const Text("Decline"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final String activeSessionId = sessionDoc.id;

                          Navigator.pop(context);
                          await sessionDoc.reference.update({
                            'status': 'accepted',
                            'connectedAt': FieldValue.serverTimestamp(),
                          });
                          setState(() => _isShowingIncomingSheet = false);

                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LiveSessionScreen(
                                  sessionId: activeSessionId,
                                  role: 'mentor',
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mentorAccentColor,
                        ),
                        child: const Text(
                          "Accept & Begin",
                          style: TextStyle(color: Colors.white),
                        ),
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
    final poolDocRef = FirebaseFirestore.instance
        .collection('available_mentors')
        .doc(uid);

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

  // --- WITHDRAWAL PAYOUT LOGIC ---
  Future<void> _requestWithdrawal(double currentEarnings) async {
    if (currentEarnings <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No available balance to withdraw.")),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Payout Request"),
        content: Text(
          "Request withdrawal for \$${currentEarnings.toStringAsFixed(2)}? Funds will be routed to your connected account.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Withdraw",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(userRef);
          double balance = (snapshot.data()?['mentorEarningsUSD'] ?? 0.0)
              .toDouble();

          if (balance < currentEarnings) {
            throw Exception("Insufficient balance.");
          }

          transaction.update(userRef, {'mentorEarningsUSD': 0.0});
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Payout request submitted successfully! Processing transfer.",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Withdrawal failed: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    if (mounted) {}
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
            icon: const Icon(
              Icons.account_balance_wallet,
              color: mentorAccentColor,
            ),
            tooltip: 'Withdraw Earnings',
            onPressed: () async {
              // Fetch latest balance from Firestore and prompt withdrawal
              if (uid != null) {
                final doc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get();
                final earnings = (doc.data()?['mentorEarningsUSD'] ?? 0.0)
                    .toDouble();
                if (mounted) _requestWithdrawal(earnings);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              if (_isOnline) await _syncOnlinePresencePool(false);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid != null
            ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots()
            : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: mentorAccentColor),
            );
          }

          double mentorEarningsUSD = 0.00;
          double connectionRatePerMin = 0.20;
          String expertiseTag = "Systems Engineer";
          bool isApproved = false;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data();
            if (data != null) {
              mentorEarningsUSD = (data['mentorEarningsUSD'] ?? 0.0).toDouble();
              connectionRatePerMin = (data['connectionRatePerMin'] ?? 0.20)
                  .toDouble();
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
                          MaterialPageRoute(
                            builder: (context) =>
                                const MentorRegistrationScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.shade700,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.gavel_rounded,
                              color: Colors.amber.shade900,
                              size: 28,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Verification Mandatory",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Tap here to link your GitHub, LinkedIn, and certificates to unlock discovery features.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.amber.shade900,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // --- ONLINE/OFFLINE SWITCH CONTROL CARD ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? mentorAccentColor.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isOnline
                            ? mentorAccentColor
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: _isOnline
                                  ? mentorAccentColor
                                  : Colors.grey,
                              size: 14,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isOnline
                                  ? "Live Pool Discovery: Active"
                                  : "Status: Hidden (Offline)",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _isOnline
                                    ? mentorAccentColor
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isOnline,
                          activeThumbColor: mentorAccentColor,
                          onChanged: (isApproved && !_isSyncing)
                              ? _syncOnlinePresencePool
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (!isApproved)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0, left: 4),
                      child: Text(
                        "*Account status must be verified before moving online.",
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      _mentorStatItem(
                        "Redeemable Wallet",
                        "\$${mentorEarningsUSD.toStringAsFixed(2)}",
                        Colors.green,
                      ),
                      const SizedBox(width: 16),
                      _mentorStatItem(
                        "Assigned Rate",
                        "\$${connectionRatePerMin.toStringAsFixed(2)}/min",
                        mentorAccentColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- WITHDRAW FUNDS ACTION BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mentorAccentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => WithdrawFundsDialog(
                            currentBalance:
                                mentorEarningsUSD, // Pass your actual mentor balance variable here
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.account_balance,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Withdraw Redeemable Funds",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- MENTEE REQUESTS MANAGEMENT SECTION ---
                  const Text(
                    "Incoming Mentee Requests",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  uid != null
                      ? StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('sessions')
                              .where('mentorId', isEqualTo: uid)
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                          builder: (context, requestSnapshot) {
                            if (requestSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            if (!requestSnapshot.hasData ||
                                requestSnapshot.data!.docs.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: const Text(
                                  "No pending requests right now. Go online to start receiving student handshakes.",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }

                            final requests = requestSnapshot.data!.docs;

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: requests.length,
                              itemBuilder: (context, index) {
                                final reqDoc = requests[index];
                                final reqData =
                                    reqDoc.data() as Map<String, dynamic>;
                                final menteeName =
                                    reqData['menteeName'] ?? 'Aspiring Student';
                                final topic =
                                    reqData['topic'] ?? 'Technical Guidance';

                                return Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: mentorAccentColor,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      menteeName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "Topic: $topic",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          ),
                                          onPressed: () async {
                                            await reqDoc.reference.update({
                                              'status': 'accepted',
                                              'connectedAt':
                                                  FieldValue.serverTimestamp(),
                                            });
                                            if (context.mounted) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      LiveSessionScreen(
                                                        sessionId: reqDoc.id,
                                                        role: 'mentor',
                                                      ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.cancel,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () async {
                                            await reqDoc.reference.update({
                                              'status': 'declined',
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : const SizedBox.shrink(),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "When visible, students searching the network can request a direct session payload handshake.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            height: 1.4,
                          ),
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
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
