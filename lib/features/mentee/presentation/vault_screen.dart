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
      backgroundColor: const Color(0xFFF8F9FF), // Matching professional light background
      appBar: AppBar(
        title: const Text("Knowledge Vault", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: uid != null
            ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
            : null,
        builder: (context, snapshot) {
          String learningHours = "0.0 hrs";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            if (data['totalMinutesLearned'] != null) {
              int mins = data['totalMinutesLearned'];
              learningHours = "${(mins / 60).toStringAsFixed(1)} hrs";
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. VAULT OVERVIEW METRIC CARD
                _buildVaultMetricsCard(learningHours),

                const SizedBox(height: 30),

                // 2. SAVED CODE REPOSITORIES SECTION
                const Text("Saved Session Code", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _buildCodeBackupItem(
                  context,
                  fileName: "main.dart",
                  projectDir: "/MentorLinks/Session_Backup",
                  language: "Dart • Flutter",
                  savedDate: "Just now (Auto-saved)",
                ),
                _buildCodeBackupItem(
                  context,
                  fileName: "plc_logic.v",
                  projectDir: "/MentorLinks/Automation_Backup",
                  language: "Verilog • OpenPLC",
                  savedDate: "3 days ago",
                ),

                const SizedBox(height: 30),

                // 3. ARCHIVED LECTURES & TIMELINE LOG
                const Text("Archived Learning Logs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _buildArchiveLogItem(
                  title: "State Management & Firestore Streams",
                  mentor: "Expert Developer",
                  cost: "-\$1.20",
                  duration: "12 mins",
                  date: "Today, 10:00 AM",
                  icon: Icons.cloud_sync,
                  iconColor: Colors.blue,
                ),
                _buildArchiveLogItem(
                  title: "Modbus TCP & Industrial Internet of Things",
                  mentor: "Automation Specialist",
                  cost: "-\$3.50",
                  duration: "35 mins",
                  date: "May 18, 2026",
                  icon: Icons.precision_manufacturing,
                  iconColor: Colors.orange,
                ),
                _buildArchiveLogItem(
                  title: "Git Workflows & Remote Repository Initialization",
                  mentor: "Senior Systems Engineer",
                  cost: "-\$2.00",
                  duration: "20 mins",
                  date: "May 14, 2026",
                  icon: Icons.code,
                  iconColor: Colors.purple,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVaultMetricsCard(String totalHours) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TOTAL KNOWLEDGE RETAINED", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(totalHours, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text("Synced with cloud repository", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ],
          ),
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white10,
            child: Icon(Icons.folder_special, color: Colors.greenAccent, size: 30),
          )
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.withOpacity(0.15))),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF333697).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.insert_drive_file, color: Color(0xFF333697)),
        ),
        title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Path: $projectDir", style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            Text(language, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        trailing: Text(savedDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        isThreeLine: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Opening localized source array for $fileName...")),
          );
        },
      ),
    );
  }

  Widget _buildArchiveLogItem({
    required String title,
    required String mentor,
    required String cost,
    required String duration,
    required String date,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(backgroundColor: iconColor.withOpacity(0.1), child: Icon(icon, color: iconColor)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Text("Mentor: $mentor • Time: $duration", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 5),
                  Text(date, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            Text(cost, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ],
        ),
      ),
    );
  }
}