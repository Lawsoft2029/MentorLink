import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mentee_discovery_screen.dart';

class CourseSelectionScreen extends StatefulWidget {
  const CourseSelectionScreen({super.key});

  @override
  State<CourseSelectionScreen> createState() => _CourseSelectionScreenState();
}

class _CourseSelectionScreenState extends State<CourseSelectionScreen> {
  final Set<String> _selectedCourseIds = {};
  final Map<String, String> _courseTitles = {};
  final Map<String, int> _courseTimelines = {};
  bool _isSaving = false;

  // Rich fallback catalog ensuring students always have quality tracks to select
  static const List<Map<String, dynamic>> _catalogCourses = [
    {
      'id': 'flutter_dev',
      'courseTitle': 'Flutter & Cross-Platform Mobile',
      'description':
          'Master Dart, Riverpod state management, Material 3 UI, and real-time Agora live sessions.',
      'icon': Icons.smartphone,
      'durationMonths': 6,
      'color': Color(0xFF333697),
    },
    {
      'id': 'python_ai',
      'courseTitle': 'Python, Applied AI & ML',
      'description':
          'Deep learning, LLMs, neural networks, PyTorch, and building intelligent agents.',
      'icon': Icons.psychology,
      'durationMonths': 6,
      'color': Colors.deepPurple,
    },
    {
      'id': 'cloud_backend',
      'courseTitle': 'Backend Architecture & Cloud Ops',
      'description':
          'Scalable Go & Node.js microservices, Firebase database operations, and Docker deployment.',
      'icon': Icons.cloud_done,
      'durationMonths': 4,
      'color': Colors.blue,
    },
    {
      'id': 'uiux_design',
      'courseTitle': 'UI/UX Product Design & Figma',
      'description':
          'Design systems, user research, wireframing in Figma, interactive design, and product psychology.',
      'icon': Icons.brush,
      'durationMonths': 3,
      'color': Colors.pinkAccent,
    },
    {
      'id': 'iot_embedded',
      'courseTitle': 'IoT Systems & Robotics',
      'description':
          'Embedded C++, ESP32, MQTT protocols, sensor arrays, and edge AI hardware integration.',
      'icon': Icons.developer_board,
      'durationMonths': 6,
      'color': Colors.orange,
    },
    {
      'id': 'cybersecurity',
      'courseTitle': 'Web Security & Ethical Hacking',
      'description':
          'Network defense, penetration testing, cryptographic protocols, and secure web auditing.',
      'icon': Icons.security,
      'durationMonths': 5,
      'color': Colors.redAccent,
    },
  ];

  Future<void> _saveSelectionAndContinue() async {
    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select at least one course to start your learning journey.",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        final List<String> enrolledTitles = [];
        final Map<String, int> finalTimelines = {};

        for (var courseId in _selectedCourseIds) {
          final title = _courseTitles[courseId] ?? courseId;
          enrolledTitles.add(title);
          finalTimelines[title] = _courseTimelines[courseId] ?? 6;

          // Seed catalog course into Firestore collection for platform consistency
          await FirebaseFirestore.instance
              .collection('courses')
              .doc(courseId)
              .set({
                'courseTitle': title,
                'durationMonths': _courseTimelines[courseId] ?? 6,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }

        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'enrolledCourses': enrolledTitles,
          'enrolledCourseIds': _selectedCourseIds.toList(),
          'courseTimelines': finalTimelines,
          'onboardingCompleted': true,
        });

        if (mounted) {
          // Direct mentee immediately to Step 3: Find Mentor with respect to chosen courses
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MenteeDiscoveryScreen(preferredCourses: enrolledTitles),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error saving courses: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Select Learning Tracks",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "What skills do you want to learn?",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "You can choose multiple courses to learn diverse skills. We'll match you with expert mentors for each track.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                if (_selectedCourseIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${_selectedCourseIds.length} course(s) selected",
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // --- DYNAMIC COURSES STREAM WITH FALLBACK CATALOG ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('courses')
                  .snapshots(),
              builder: (context, snapshot) {
                // Determine course items: use Firestore docs or fallback to built-in catalog
                List<Map<String, dynamic>> displayCourses = [];

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  displayCourses = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {
                      'id': doc.id,
                      'courseTitle':
                          data['courseTitle'] ?? 'Software Engineering Track',
                      'description':
                          data['description'] ??
                          'Master industry-standard skills with 1-on-1 mentorship.',
                      'durationMonths': data['durationMonths'] ?? 6,
                      'icon': Icons.code,
                      'color': primaryColor,
                    };
                  }).toList();
                } else {
                  displayCourses = _catalogCourses;
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayCourses.length,
                  itemBuilder: (context, index) {
                    final course = displayCourses[index];
                    final courseId = course['id'].toString();
                    final title = course['courseTitle'] as String;
                    final description = course['description'] as String;
                    final defaultMonths = (course['durationMonths'] as num)
                        .toInt();
                    final IconData icon = course['icon'] is IconData
                        ? course['icon'] as IconData
                        : Icons.school;
                    final Color color = course['color'] is Color
                        ? course['color'] as Color
                        : primaryColor;

                    final isSelected = _selectedCourseIds.contains(courseId);
                    int currentMonths =
                        _courseTimelines[courseId] ?? defaultMonths;

                    return Card(
                      elevation: isSelected ? 3 : 1,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? primaryColor
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedCourseIds.remove(courseId);
                              _courseTitles.remove(courseId);
                              _courseTimelines.remove(courseId);
                            } else {
                              _selectedCourseIds.add(courseId);
                              _courseTitles[courseId] = title;
                              _courseTimelines[courseId] = defaultMonths;
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: color.withValues(
                                      alpha: 0.12,
                                    ),
                                    radius: 22,
                                    child: Icon(icon, color: color, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isSelected
                                            ? primaryColor
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedCourseIds.add(courseId);
                                          _courseTitles[courseId] = title;
                                          _courseTimelines[courseId] =
                                              defaultMonths;
                                        } else {
                                          _selectedCourseIds.remove(courseId);
                                          _courseTitles.remove(courseId);
                                          _courseTimelines.remove(courseId);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 58.0,
                                  right: 12,
                                  top: 4,
                                ),
                                child: Text(
                                  description,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ),

                              // Timeline duration slider when selected
                              if (isSelected) ...[
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Target Completion Timeline:",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                      Text(
                                        "$currentMonths Months",
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Slider(
                                  value: currentMonths.toDouble(),
                                  min: 1,
                                  max: 12,
                                  divisions: 11,
                                  activeColor: primaryColor,
                                  label: "$currentMonths Months",
                                  onChanged: (double value) {
                                    setState(() {
                                      _courseTimelines[courseId] = value
                                          .toInt();
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // --- BOTTOM SAVE & PROCEED BUTTON ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                onPressed: _isSaving ? null : _saveSelectionAndContinue,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Courses & Find Mentors",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
