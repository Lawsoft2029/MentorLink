import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/scheduling_service.dart';
import '../../auth/presentation/welcome_screen.dart';
import '../../profile/presentation/profile_dashboard_screen.dart';
import 'course_selection_screen.dart';
import 'mentee_discovery_screen.dart';
import 'live_session_screen.dart';
import '../../chat/presentation/chat_discussion_screen.dart';

class MenteeLearningHubScreen extends StatefulWidget {
  const MenteeLearningHubScreen({super.key});

  @override
  State<MenteeLearningHubScreen> createState() =>
      _MenteeLearningHubScreenState();
}

class _MenteeLearningHubScreenState extends State<MenteeLearningHubScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    final List<Widget> pages = [
      const MenteeHubHomeContent(),
      const MenteeDiscoveryScreen(),
      const MenteeActiveChatsView(),
      const ProfileDashboardScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: "Learning Hub",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_search),
            label: "Find Mentors",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Chats",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

class MenteeHubHomeContent extends StatelessWidget {
  const MenteeHubHomeContent({super.key});

  Future<void> _startClass({
    required BuildContext context,
    required String sessionId,
    required String courseTitle,
    required String mentorName,
  }) async {
    final schedulingService = SchedulingService();

    // 1. Mark session live and notify mentor
    await schedulingService.triggerStartClass(
      sessionId: sessionId,
      initiatedByRole: 'mentee',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Starting $courseTitle! Mentor $mentorName has been notified to join on app/web.",
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 2. Launch Agora RTC Live Session
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              LiveSessionScreen(sessionId: sessionId, role: 'mentee'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text(
          "Mentee Learning Hub",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: primaryColor),
            tooltip: "My Profile",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileDashboardScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "Log Out",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text("Please sign in."))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

                final userData = userSnapshot.data?.data() ?? {};
                final studentName =
                    userData['legalName'] ?? userData['name'] ?? 'Scholar';
                final List<dynamic> enrolledCourses =
                    userData['enrolledCourses'] ?? [];
                final Map<String, dynamic> courseTimelines =
                    userData['courseTimelines'] ?? {};

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- WELCOME & STATUS BANNER ---
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF333697), Color(0xFF4A4EC7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: Icon(
                                Icons.school,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Welcome Back, $studentName!",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${enrolledCourses.length} active skill track(s) enrolled",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.white,
                                size: 28,
                              ),
                              tooltip: "Enroll in More Courses",
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CourseSelectionScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- ENROLLED COURSES (MULTIPLE SKILLS) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "My Enrolled Skills",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CourseSelectionScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text(
                              "Manage Tracks",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (enrolledCourses.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.school_outlined,
                                color: Colors.grey,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  "No courses enrolled yet. Choose from our tech catalog to start learning!",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CourseSelectionScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text(
                                  "Pick Skills",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 125,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: enrolledCourses.length,
                            itemBuilder: (context, index) {
                              final course = enrolledCourses[index].toString();
                              final timelineMonths =
                                  courseTimelines[course] ?? 6;

                              return Container(
                                width: 220,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.03,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: primaryColor
                                              .withValues(alpha: 0.1),
                                          child: const Icon(
                                            Icons.code,
                                            color: primaryColor,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            course,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "$timelineMonths Months Master Track",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 30,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  MenteeDiscoveryScreen(
                                                    preferredCourses: [course],
                                                  ),
                                            ),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: primaryColor,
                                          ),
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.search,
                                          size: 12,
                                          color: primaryColor,
                                        ),
                                        label: const Text(
                                          "Find Mentor",
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 28),

                      // --- UPCOMING CLASSES & SCHEDULE (REQUIREMENT 7) ---
                      const Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: primaryColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Upcoming Classes & Schedule",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('sessions')
                            .where('menteeId', isEqualTo: uid)
                            .snapshots(),
                        builder: (context, sessionSnapshot) {
                          if (sessionSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            );
                          }

                          final sessions = sessionSnapshot.data?.docs ?? [];

                          if (sessions.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_note,
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "No upcoming classes scheduled yet.",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Find your mentor, chat about your class timings, and their schedule will appear right here!",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const MenteeDiscoveryScreen(),
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
                                      Icons.person_search,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      "Browse Mentors",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sessions.length,
                            itemBuilder: (context, index) {
                              final sessionDoc = sessions[index];
                              final sessionData = sessionDoc.data();
                              final sessionId = sessionDoc.id;

                              final courseTitle =
                                  sessionData['courseTitle'] ??
                                  sessionData['topic'] ??
                                  'Mentorship Class';
                              final mentorName =
                                  sessionData['mentorName'] ?? 'Expert Mentor';
                              final mentorId = sessionData['mentorId'] ?? '';
                              final time = sessionData['time'] ?? '16:00';
                              final days =
                                  sessionData['days'] ??
                                  sessionData['date'] ??
                                  'Weekly';
                              final status =
                                  sessionData['status'] ?? 'Scheduled';
                              final bool isLive =
                                  status == 'live' || status == 'ready';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 14),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isLive
                                        ? Colors.green
                                        : Colors.grey.shade200,
                                    width: isLive ? 2 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              courseTitle,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: primaryColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isLive
                                                  ? Colors.green.shade50
                                                  : Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isLive
                                                    ? Colors.green.shade300
                                                    : Colors.orange.shade200,
                                              ),
                                            ),
                                            child: Text(
                                              isLive
                                                  ? "● LIVE NOW"
                                                  : "Scheduled",
                                              style: TextStyle(
                                                color: isLive
                                                    ? Colors.green.shade800
                                                    : Colors.orange.shade800,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 18,
                                            backgroundColor: primaryColor,
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Mentor: $mentorName",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                "Class Time: $days at $time",
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ChatDiscussionScreen(
                                                        recipientId: mentorId,
                                                        recipientName:
                                                            mentorName,
                                                        courseTitle:
                                                            courseTitle,
                                                      ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.chat_bubble_outline,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              "Chat Mentor",
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),

                                          // STEP 6: START / JOIN CLASS ACTION
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isLive
                                                  ? Colors.green
                                                  : primaryColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                            ),
                                            onPressed: () => _startClass(
                                              context: context,
                                              sessionId: sessionId,
                                              courseTitle: courseTitle,
                                              mentorName: mentorName,
                                            ),
                                            icon: const Icon(
                                              Icons.video_call,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            label: Text(
                                              isLive
                                                  ? "Join Live Class"
                                                  : "Start Class",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
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
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class MenteeActiveChatsView extends StatelessWidget {
  const MenteeActiveChatsView({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Mentor Chats",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0.5,
      ),
      body: uid == null
          ? const Center(child: Text("Please sign in."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .where('participants', arrayContains: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                final rooms = snapshot.data?.docs ?? [];

                if (rooms.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "No active conversations yet.",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Find a mentor for your courses and start discussing your learning schedule!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final data = rooms[index].data() as Map<String, dynamic>;
                    final course = data['courseContext'] ?? 'Tech Mentorship';
                    final lastMessage =
                        data['lastMessage'] ?? 'Tap to chat with mentor.';
                    final List participants = data['participants'] ?? [];
                    final counterpartId = participants.firstWhere(
                      (id) => id != uid,
                      orElse: () => '',
                    );

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: primaryColor,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          course,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDiscussionScreen(
                                recipientId: counterpartId,
                                recipientName: "Expert Mentor",
                                courseTitle: course,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
