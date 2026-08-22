import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mentorlinks_app_project/features/chat/presentation/chat_discussion_screen.dart';

class MenteeScheduleScreen extends StatelessWidget {
  const MenteeScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'My Learning Roadmaps',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0.5,
      ),
      body: uid == null
          ? const Center(child: Text("Please log in to view your schedule."))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Center(child: Text("User profile not found."));
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final List<dynamic> enrolledCourseIds =
                    userData['enrolledCourses'] ?? [];
                final Map<String, dynamic> courseTimelines =
                    userData['courseTimelines'] ?? {};

                if (enrolledCourseIds.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "You haven't enrolled in any tech tracks yet.",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                            ),
                            onPressed: () {
                              // Navigate to course selection screen
                            },
                            child: const Text(
                              "Explore Courses",
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
                  itemCount: enrolledCourseIds.length,
                  itemBuilder: (context, index) {
                    final courseId = enrolledCourseIds[index].toString();
                    final int totalMonths = courseTimelines[courseId] ?? 6;

                    // Fetch course details dynamically from the courses collection
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('courses')
                          .doc(courseId)
                          .get(),
                      builder: (context, courseSnapshot) {
                        if (!courseSnapshot.hasData ||
                            !courseSnapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }

                        final courseData =
                            courseSnapshot.data!.data() as Map<String, dynamic>;
                        final title =
                            courseData['courseTitle'] ?? 'Tech Course';
                        final description =
                            courseData['description'] ??
                            'Active engineering track.';

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "$totalMonths Months Track",
                                        style: const TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const LinearProgressIndicator(
                                  value:
                                      0.25, // Example progress (e.g. Month 2 of 6)
                                  backgroundColor: Colors.black12,
                                  color: primaryColor,
                                  minHeight: 6,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Status: In Progress",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ChatDiscussionScreen(
                                                  recipientId:
                                                      'MENTOR_UID_FROM_COURSE_DOC',
                                                  recipientName:
                                                      'Assigned Mentor',
                                                  courseTitle: title,
                                                ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.chat_bubble_outline,
                                        size: 16,
                                        color: primaryColor,
                                      ),
                                      label: const Text(
                                        "Discuss Schedule",
                                        style: TextStyle(color: primaryColor),
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
                );
              },
            ),
    );
  }
}
