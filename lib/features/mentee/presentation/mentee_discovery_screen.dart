import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/widgets/star_rating_widget.dart'; // Adjust path if your shared folder is structured differently

class MenteeDiscoveryScreen extends StatelessWidget {
  const MenteeDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Discover Expert Mentors', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query Firestore for users whose role is set to 'mentor' and are approved
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'mentor')
            .where('isApproved', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      "No verified mentors available right now.",
                      style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final mentors = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mentors.length,
            itemBuilder: (context, index) {
              final mentorData = mentors[index].data() as Map<String, dynamic>;
              
              final email = mentorData['email'] ?? 'Expert Mentor';
              final expertise = mentorData['expertiseTag'] ?? 'General Engineering & Tech';
              final bio = mentorData['bio'] ?? 'No biography provided yet.';
              final ratePerMin = (mentorData['connectionRatePerMin'] ?? 0.20).toDouble();
              
              // Grab the rating fields we built in Item 2
              final double rating = (mentorData['averageRating'] ?? 5.0).toDouble();
              final int reviewCount = (mentorData['totalReviewsCount'] ?? 0).toInt();

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: primaryColor.withValues(alpha: 0.1),
                            child: const Icon(Icons.school, color: primaryColor, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  expertise,
                                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          // Display Charge Rate Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "\$${ratePerMin.toStringAsFixed(2)}/min",
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        bio,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Live Star Rating Badge Component
                          StarRatingWidget(rating: rating, reviewCount: reviewCount),
                          
                          // Request Session Button
                          ElevatedButton.icon(
                            onPressed: () {
                              // Navigate to a simple session request screen
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SessionRequestScreen(
                                    mentorEmail: email,
                                    ratePerMin: ratePerMin,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.video_call, size: 18),
                            label: const Text("Request Session"),
                          ),
                        ],
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

// Simple session request screen placeholder
class SessionRequestScreen extends StatelessWidget {
  final String mentorEmail;
  final double ratePerMin;

  const SessionRequestScreen({super.key, required this.mentorEmail, required this.ratePerMin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Session')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mentor: $mentorEmail', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Rate: \$${""}${ratePerMin.toStringAsFixed(2)}/min', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Placeholder action for initiating session
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session request sent')));
                Navigator.of(context).pop();
              },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }
}