// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text(
          "Knowledge Vault",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: uid != null
            ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots()
            : null,
        builder: (context, snapshot) {
          String learningHours = "0.0 hrs";
          String userTier = "Freemium";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            if (data['totalMinutesLearned'] != null) {
              // Safely handle both double and int values from Firestore
              double mins = (data['totalMinutesLearned'] as num).toDouble();
              learningHours = "${(mins / 60).toStringAsFixed(1)} hrs";
            }
            userTier = data['userTier'] ?? 'Freemium';
          }

          bool hasVaultAccess =
              userTier == 'Premium' || userTier == 'Enterprise';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. VAULT OVERVIEW METRIC CARD
                _buildVaultMetricsCard(learningHours, userTier),

                const SizedBox(height: 25),

                // 2. SESSION NOTES VAULT SECTION
                const Text(
                  "Session Notes Vault",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                hasVaultAccess || uid != null
                    ? _buildSessionNotesList(uid)
                    : _buildLockedTierNotice(
                        "Upgrade to Premium or Enterprise to access offline session notes.",
                      ),

                const SizedBox(height: 25),

                // 3. CLASS RECORDINGS VAULT SECTION (NEW)
                const Text(
                  "Class Recordings Vault",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                hasVaultAccess || uid != null
                    ? _buildSessionRecordingsList(uid)
                    : _buildLockedTierNotice(
                        "Upgrade to Premium or Enterprise to access class video & audio recordings.",
                      ),

                const SizedBox(height: 25),

                // 4. SAVED CODE REPOSITORIES SECTION
                const Text(
                  "Saved Session Code",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                _buildCodeBackupItem(
                  context,
                  fileName: "main.dart",
                  projectDir: "/MentorLinks/Session_Backup",
                  language: "Dart • Flutter",
                  savedDate: "Just now (Auto-saved)",
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVaultMetricsCard(String totalHours, String tier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TIER: ${tier.toUpperCase()}",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "TOTAL KNOWLEDGE RETAINED",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                totalHours,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "Cloud & Offline Synchronized",
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white10,
            child: Icon(
              Icons.folder_special,
              color: Colors.greenAccent,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  // --- STREAM BUILDER FOR SESSION NOTES ---
  Widget _buildSessionNotesList(String? uid) {
    if (uid == null) return const Text("Please log in to view saved notes.");

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('session_notes')
          .orderBy('lastUpdated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            "No session notes recorded yet.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          );
        }

        final notes = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final noteData = notes[index].data() as Map<String, dynamic>;
            final content = noteData['noteContent'] ?? 'Empty note';
            final sessionId = noteData['sessionId'] ?? 'Session';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.15)),
              ),
              child: ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.blueAccent),
                title: Text(
                  "Note: ${sessionId.substring(0, sessionId.length > 6 ? 6 : sessionId.length)}...",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        "Review Note (${sessionId.substring(0, sessionId.length > 6 ? 6 : sessionId.length)})",
                      ),
                      content: SingleChildScrollView(child: Text(content)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // --- STREAM BUILDER FOR CLASS RECORDINGS ---
  Widget _buildSessionRecordingsList(String? uid) {
    if (uid == null) return const Text("Please log in to view recordings.");

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('session_recordings')
          .orderBy('recordedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            "No class recordings available yet.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          );
        }

        final recordings = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recordings.length,
          itemBuilder: (context, index) {
            final recData = recordings[index].data() as Map<String, dynamic>;
            final sessionId = recData['sessionId'] ?? 'Session';
            final duration = (recData['durationMinutes'] ?? 0.0) as num;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.15)),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF3E5F5),
                  child: Icon(Icons.play_arrow, color: Colors.purple),
                ),
                title: Text(
                  "Class Recording (${sessionId.substring(0, sessionId.length > 6 ? 6 : sessionId.length)}...)",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  "Duration: ${duration.toDouble().toStringAsFixed(1)} mins • Offline Ready",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.download_done,
                  color: Colors.green,
                  size: 18,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Loading recording for session ${sessionId.substring(0, sessionId.length > 6 ? 6 : sessionId.length)}...",
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLockedTierNotice(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBackupItem(
    BuildContext context, {
    required String fileName,
    required String projectDir,
    required String language,
    required String savedDate,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF333697).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.insert_drive_file, color: Color(0xFF333697)),
        ),
        title: Text(
          fileName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Path: $projectDir",
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            Text(
              language,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: Text(
          savedDate,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        isThreeLine: true,
      ),
    );
  }
}
