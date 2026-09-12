import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/matching_service.dart';
import '../../chat/presentation/chat_discussion_screen.dart';

class MentorMatchingScreen extends StatefulWidget {
  final String menteeSkillInterest; // e.g., "Flutter"

  const MentorMatchingScreen({super.key, required this.menteeSkillInterest});

  @override
  State<MentorMatchingScreen> createState() => _MentorMatchingScreenState();
}

class _MentorMatchingScreenState extends State<MentorMatchingScreen> {
  final MatchingService _matchingService = MatchingService();

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    return Scaffold(
      appBar: AppBar(
        title: Text("Matched Mentors: ${widget.menteeSkillInterest}"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _matchingService.getMatchedMentors(widget.menteeSkillInterest),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final mentors = snapshot.data?.docs ?? [];

          if (mentors.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_search,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No direct mentors found with tag '${widget.menteeSkillInterest}'.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Explore All Mentors",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mentors.length,
            itemBuilder: (context, index) {
              final doc = mentors[index];
              final mentor = doc.data();
              final mentorId = doc.id;
              final mentorName =
                  mentor['name'] ?? mentor['fullName'] ?? 'Expert Mentor';
              final mentorBio = mentor['bio'] ?? 'Senior Software Professional';
              final hourlyRate = mentor['hourlyRate'] ?? '50';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: primaryColor,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mentorName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mentorBio,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "\$$hourlyRate / hr",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00796B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Connects directly to Chat Discussion
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDiscussionScreen(
                                recipientId: mentorId,
                                recipientName: mentorName,
                                courseTitle: widget.menteeSkillInterest,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Discuss",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
