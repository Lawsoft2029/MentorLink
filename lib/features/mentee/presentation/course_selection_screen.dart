import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseSelectionScreen extends StatefulWidget {
  const CourseSelectionScreen({super.key});

  @override
  State<CourseSelectionScreen> createState() => _CourseSelectionScreenState();
}

class _CourseSelectionScreenState extends State<CourseSelectionScreen> {
  // Store selected course IDs and their custom timeline durations in months
  final Set<String> _selectedCourseIds = {};
  final Map<String, int> _courseTimelines = {};
  bool _isSaving = false;

  Future<void> _saveSelectionAndContinue() async {
    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one course to continue.")),
      );
      return;
    }

    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        // Filter timelines to only include selected courses and assign default 6 months if missing
        final Map<String, int> finalTimelines = {};
        for (var courseId in _selectedCourseIds) {
          finalTimelines[courseId] = _courseTimelines[courseId] ?? 6;
        }

        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'enrolledCourses': _selectedCourseIds.toList(),
          'courseTimelines': finalTimelines,
          'onboardingCompleted': true,
        });

        if (mounted) {
          // Pop or navigate to Mentee Dashboard / Discovery
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving courses: $e"), backgroundColor: Colors.red),
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
        title: const Text("Select Learning Tracks", style: TextStyle(fontWeight: FontWeight.bold)),
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
              children: const [
                Text(
                  "Choose your desired tech tracks",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                SizedBox(height: 6),
                Text(
                  "You can select multiple courses and customize your timeline schedule with expert mentors.",
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // --- DYNAMIC COURSES STREAM BUILDER ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('courses').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No courses available in catalog right now.", style: TextStyle(color: Colors.grey)),
                  );
                }

                final courses = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final doc = courses[index];
                    final courseId = doc.id;
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final title = data['courseTitle'] ?? 'Engineering Course';
                    final description = data['description'] ?? 'Master industry-standard software skills.';
                    final defaultMonths = data['durationMonths'] ?? 6;

                    final isSelected = _selectedCourseIds.contains(courseId);
                    int currentMonths = _courseTimelines[courseId] ?? defaultMonths;

                    return Card(
                      elevation: isSelected ? 2 : 1,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? primaryColor : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: primaryColor,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedCourseIds.add(courseId);
                                        _courseTimelines[courseId] = defaultMonths;
                                      } else {
                                        _selectedCourseIds.remove(courseId);
                                        _courseTimelines.remove(courseId);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 40.0, right: 12),
                              child: Text(
                                description,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.3),
                              ),
                            ),
                            
                            // Show timeline slider if course is selected
                            if (isSelected) ...[
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.only(left: 12.0, right: 12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Timeline Schedule:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                    Text("$currentMonths Months", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor)),
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
                                    _courseTimelines[courseId] = value.toInt();
                                  });
                                },
                              ),
                            ],
                          ],
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
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSaving ? null : _saveSelectionAndContinue,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Roadmap & Enter Academy",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}