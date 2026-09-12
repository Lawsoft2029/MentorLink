import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import 'package:mentorlinks_app_project/features/chat/presentation/chat_discussion_screen.dart';

class MenteeDiscoveryScreen extends StatefulWidget {
  final List<String>? preferredCourses;

  const MenteeDiscoveryScreen({super.key, this.preferredCourses});

  @override
  State<MenteeDiscoveryScreen> createState() => _MenteeDiscoveryScreenState();
}

class _MenteeDiscoveryScreenState extends State<MenteeDiscoveryScreen> {
  String? _selectedCourseFilter;

  // Fallback demo mentors when Firestore collection is freshly initiated
  static const List<Map<String, dynamic>> _demoMentors = [
    {
      'id': 'mentor_samuel_flutter',
      'email': 'samuel.dev@mentorlinks.com',
      'name': 'Engr. Samuel Okon',
      'expertiseTag': 'Flutter & Cross-Platform Mobile',
      'bio':
          'Senior Mobile Architect with 7+ years developing scalable Flutter & Dart apps, Firebase integrations, and RTC video streaming.',
      'connectionRatePerMin': 0.15,
      'averageRating': 4.9,
      'totalReviewsCount': 84,
    },
    {
      'id': 'mentor_elena_ai',
      'email': 'elena.ai@mentorlinks.com',
      'name': 'Dr. Elena Rostova',
      'expertiseTag': 'Python, Applied AI & ML',
      'bio':
          'AI Research Engineer specializing in PyTorch deep learning, LLM fine-tuning, computer vision, and autonomous agent systems.',
      'connectionRatePerMin': 0.25,
      'averageRating': 5.0,
      'totalReviewsCount': 112,
    },
    {
      'id': 'mentor_marcus_cloud',
      'email': 'marcus.cloud@mentorlinks.com',
      'name': 'Marcus Vance',
      'expertiseTag': 'Backend Architecture & Cloud Ops',
      'bio':
          'Cloud Solutions Architect. Specializes in Go, Node.js microservices, Docker clusters, and real-time WebSocket systems.',
      'connectionRatePerMin': 0.20,
      'averageRating': 4.8,
      'totalReviewsCount': 63,
    },
    {
      'id': 'mentor_amara_uiux',
      'email': 'amara.design@mentorlinks.com',
      'name': 'Amara Kalu',
      'expertiseTag': 'UI/UX Product Design & Figma',
      'bio':
          'Lead Product Designer. Teaches Figma design systems, wireframing, high-fidelity prototyping, and developer handoffs.',
      'connectionRatePerMin': 0.12,
      'averageRating': 4.9,
      'totalReviewsCount': 76,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preferredCourses != null &&
        widget.preferredCourses!.isNotEmpty) {
      _selectedCourseFilter = widget.preferredCourses!.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Find Expert Mentors',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0.5,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner for selected courses
          if (widget.preferredCourses != null &&
              widget.preferredCourses!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: primaryColor.withValues(alpha: 0.05),
              child: Row(
                children: [
                  const Icon(Icons.school, size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Showing mentors matching your ${widget.preferredCourses!.length} selected track(s)",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // --- HORIZONTAL COURSE SELECTOR ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Filter by Skill Track",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (_selectedCourseFilter != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedCourseFilter = null),
                    child: const Text(
                      "Clear Filter",
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(
            height: 48,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('courses')
                  .snapshots(),
              builder: (context, courseSnapshot) {
                final List<String> availableTracks = [];

                if (courseSnapshot.hasData &&
                    courseSnapshot.data!.docs.isNotEmpty) {
                  for (var doc in courseSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['courseTitle'];
                    if (title != null && !availableTracks.contains(title)) {
                      availableTracks.add(title);
                    }
                  }
                }

                // Add preferred courses if missing
                if (widget.preferredCourses != null) {
                  for (var c in widget.preferredCourses!) {
                    if (!availableTracks.contains(c)) availableTracks.add(c);
                  }
                }

                // Default fallback tracks
                if (availableTracks.isEmpty) {
                  availableTracks.addAll([
                    'Flutter & Cross-Platform Mobile',
                    'Python, Applied AI & ML',
                    'Backend Architecture & Cloud Ops',
                    'UI/UX Product Design & Figma',
                  ]);
                }

                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // "All Tracks" Option
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
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          setState(() => _selectedCourseFilter = null);
                        },
                      ),
                    ),
                    ...availableTracks.map((courseTitle) {
                      final isSelected = _selectedCourseFilter == courseTitle;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(courseTitle),
                          selected: isSelected,
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
          const SizedBox(height: 6),

          // --- MENTOR LISTVIEW STREAM ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: () {
                Query query = FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'mentor');

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

                // If Firestore has mentors, use them; otherwise show fallback demo mentors
                List<Map<String, dynamic>> mentorList = [];

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  mentorList = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {
                      'id': doc.id,
                      'name':
                          data['name'] ??
                          data['fullName'] ??
                          data['email'] ??
                          'Expert Mentor',
                      'email': data['email'] ?? '',
                      'expertiseTag':
                          data['expertiseTag'] ??
                          data['skills']?.join(', ') ??
                          'Engineering Specialist',
                      'bio':
                          data['bio'] ??
                          'Experienced engineering mentor ready to guide your learning roadmap.',
                      'connectionRatePerMin':
                          (data['connectionRatePerMin'] ?? 0.15).toDouble(),
                      'averageRating': (data['averageRating'] ?? 4.9)
                          .toDouble(),
                      'totalReviewsCount': (data['totalReviewsCount'] ?? 24)
                          .toInt(),
                    };
                  }).toList();
                } else {
                  // Filter demo mentors by course if filter applied
                  mentorList = _demoMentors.where((m) {
                    if (_selectedCourseFilter == null) return true;
                    return m['expertiseTag'].toString().toLowerCase().contains(
                      _selectedCourseFilter!.toLowerCase(),
                    );
                  }).toList();
                  if (mentorList.isEmpty) mentorList = _demoMentors;
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: mentorList.length,
                  itemBuilder: (context, index) {
                    final mentor = mentorList[index];
                    final mentorId = mentor['id'];
                    final mentorName = mentor['name'] ?? 'Expert Mentor';
                    final expertise =
                        mentor['expertiseTag'] ?? 'Tech Specialist';
                    final bio = mentor['bio'] ?? '';
                    final ratePerMin = (mentor['connectionRatePerMin'] as num)
                        .toDouble();
                    final rating = (mentor['averageRating'] as num).toDouble();
                    final reviewCount = (mentor['totalReviewsCount'] as num)
                        .toInt();

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
                                        mentorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        expertise,
                                        style: const TextStyle(
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
                                fontSize: 13,
                                height: 1.35,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 14),
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
                                    // STEP 4: Chat with mentor about how class will be held
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ChatDiscussionScreen(
                                              recipientId: mentorId,
                                              recipientName: mentorName,
                                              courseTitle: expertise,
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
                                  icon: const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    "Discuss & Plan Class",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
