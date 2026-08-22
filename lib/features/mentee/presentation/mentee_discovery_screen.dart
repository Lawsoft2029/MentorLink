import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import 'package:mentorlinks_app_project/features/chat/presentation/chat_discussion_screen.dart';

class MenteeDiscoveryScreen extends StatefulWidget {
  const MenteeDiscoveryScreen({super.key});

  @override
  State<MenteeDiscoveryScreen> createState() => _MenteeDiscoveryScreenState();
}

class _MenteeDiscoveryScreenState extends State<MenteeDiscoveryScreen> {
  String?
  _selectedCourseFilter; // Filter mentors by selected dynamic course tag

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Discover Expert Mentors',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- DYNAMIC TECH COURSE HORIZONTAL SELECTOR ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: const Text(
              "Filter by Tech Course",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('courses')
                  .snapshots(),
              builder: (context, courseSnapshot) {
                if (!courseSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final courses = courseSnapshot.data!.docs;

                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // "All Courses" Option
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: const Text("All Tracks"),
                        selected: _selectedCourseFilter == null,
                        selectedColor: primaryColor,
                        labelStyle: TextStyle(
                          color: _selectedCourseFilter == null
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          setState(() => _selectedCourseFilter = null);
                        },
                      ),
                    ),
                    // Dynamic Courses from Firestore
                    ...courses.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final courseTitle = data['courseTitle'] ?? 'Tech Track';

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(courseTitle),
                          selected: _selectedCourseFilter == courseTitle,
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: _selectedCourseFilter == courseTitle
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedCourseFilter = selected
                                  ? courseTitle
                                  : null;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // --- MENTOR LISTVIEW STREAM ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: () {
                Query query = FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'mentor')
                    .where('isApproved', isEqualTo: true);

                if (_selectedCourseFilter != null) {
                  query = query.where(
                    'expertiseTag',
                    isEqualTo: _selectedCourseFilter,
                  );
                }

                return query.snapshots();
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No verified mentors available for this track right now.",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
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
                    final mentorData =
                        mentors[index].data() as Map<String, dynamic>;

                    final email = mentorData['email'] ?? 'Expert Mentor';
                    final expertise =
                        mentorData['expertiseTag'] ??
                        'General Engineering & Tech';
                    final bio =
                        mentorData['bio'] ?? 'No biography provided yet.';
                    final ratePerMin =
                        (mentorData['connectionRatePerMin'] ?? 0.20).toDouble();

                    final double rating = (mentorData['averageRating'] ?? 5.0)
                        .toDouble();
                    final int reviewCount =
                        (mentorData['totalReviewsCount'] ?? 0).toInt();

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                                  backgroundColor: primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: const Icon(
                                    Icons.school,
                                    color: primaryColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        email,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        expertise,
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "\$${ratePerMin.toStringAsFixed(2)}/min",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              bio,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                StarRatingWidget(
                                  rating: rating,
                                  reviewCount: reviewCount,
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
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
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.video_call, size: 18),
                                  label: const Text("Request Session"),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.chat,
                                    color: primaryColor,
                                  ),
                                  tooltip: "Discuss with Mentor",
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ChatDiscussionScreen(
                                              recipientId: mentors[index].id,
                                              recipientName: email,
                                              courseTitle: expertise,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
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
          ),
        ],
      ),
    );
  }
}

class SessionRequestScreen extends StatelessWidget {
  final String mentorEmail;
  final double ratePerMin;

  const SessionRequestScreen({
    super.key,
    required this.mentorEmail,
    required this.ratePerMin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Session')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mentor: $mentorEmail',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Rate: \$${ratePerMin.toStringAsFixed(2)}/min',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session request sent')),
                );
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
