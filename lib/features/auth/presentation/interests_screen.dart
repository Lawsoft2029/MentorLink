import 'package:flutter/material.dart';
import 'package:mentorlinks_app_project/features/mentee/presentation/mentee_home_screen.dart  ';

class CourseSelectionScreen extends StatefulWidget {
  const CourseSelectionScreen({super.key});

  @override
  State<CourseSelectionScreen> createState() => _CourseSelectionScreenState();
}

class _CourseSelectionScreenState extends State<CourseSelectionScreen> {
  // Define our professional course list with icons
  final List<Map<String, dynamic>> _courses = [
    {"name": "Flutter Dev", "icon": Icons.smartphone, "color": Colors.blue},
    {"name": "IoT Systems", "icon": Icons.developer_board, "color": Colors.orange},
    {"name": "Python Data", "icon": Icons.analytics, "color": Colors.green},
    {"name": "UI/UX Design", "icon": Icons.brush, "color": Colors.pink},
    {"name": "Firebase Ops", "icon": Icons.storage, "color": Colors.amber},
    {"name": "Web Security", "icon": Icons.security, "color": Colors.red},
    {"name": "Dart Lang", "icon": Icons.code, "color": Colors.cyan},
    {"name": "AI Basics", "icon": Icons.psychology, "color": Colors.deepPurple},
  ];

  String? _selectedCourse;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Select a Course", style: TextStyle(color: Colors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "What do you want\nto master?",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333697)),
            ),
            const SizedBox(height: 20),
            
            // Search bar for courses
            TextField(
              decoration: InputDecoration(
                hintText: "Search for a course...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 25),

            // Grid of Courses
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // Two columns
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                ),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  final isSelected = _selectedCourse == course['name'];

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCourse = course['name']),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF333697) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected ? null : Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            course['icon'], 
                            size: 40, 
                            color: isSelected ? Colors.white : course['color']
                          ),
                          const SizedBox(height: 12),
                          Text(
                            course['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Action Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _selectedCourse == null ? null : () {
                    // Navigate to Discovery Screen
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const MenteeHomeScreen())
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333697),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text("START LEARNING", 
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    )
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}