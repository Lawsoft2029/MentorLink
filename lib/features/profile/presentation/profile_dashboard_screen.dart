import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/scheduling_service.dart';

class ProfileDashboardScreen extends StatefulWidget {
  const ProfileDashboardScreen({super.key});

  @override
  State<ProfileDashboardScreen> createState() => _ProfileDashboardScreenState();
}

class _ProfileDashboardScreenState extends State<ProfileDashboardScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final SchedulingService schedulingService = SchedulingService();

  bool _isEditing = false;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  
  String _selectedGender = 'Male';
  String _selectedCountry = 'Nigeria';
  List<String> _selectedCourses = [];

  final List<String> _availableCourses = [
    'Cross-Platform Flutter',
    'IoT & Automation',
    'UI/UX Design',
    'Backend Architecture',
    'Fintech Integration'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? user?.displayName ?? '';
          _ageController.text = (data['age'] ?? '').toString();
          _selectedGender = data['gender'] ?? 'Male';
          _selectedCountry = data['country'] ?? 'Nigeria';
          _selectedCourses = List<String>.from(data['coursesOfInterest'] ?? []);
        });
      }
    } catch (e) {
      // Handle error gracefully
    }
  }

  Future<void> _saveProfile() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'gender': _selectedGender,
        'country': _selectedCountry,
        'coursesOfInterest': _selectedCourses,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Learning Profile"),
        backgroundColor: const Color(0xFF333697),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF333697).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFF333697).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Color(0xFF333697),
                        child: Icon(Icons.person, size: 40, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text.isEmpty ? (user?.displayName ?? "Learner") : _nameController.text,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333697),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? "user@mentorlinks.com",
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "Pro Member",
                                style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedGender,
                            decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                            items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) => setState(() => _selectedGender = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCountry,
                      decoration: const InputDecoration(labelText: "Country / Jurisdiction", border: OutlineInputBorder()),
                      items: ['Nigeria', 'United Kingdom', 'United States', 'Canada', 'Germany', 'Other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCountry = val!),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Courses of Interest:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      children: _availableCourses.map((course) {
                        final isSelected = _selectedCourses.contains(course);
                        return FilterChip(
                          label: Text(course),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCourses.add(course);
                              } else {
                                _selectedCourses.remove(course);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333697)),
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Save Profile Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Reminder Notification Section Header
            const Row(
              children: [
                Icon(Icons.notification_important, color: Color(0xFF00796B)),
                SizedBox(width: 8),
                Text(
                  "Upcoming Class Reminders",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333697),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live Stream of Upcoming Sessions with Reminders
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: schedulingService.getUpcomingSessions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Icon(Icons.event_available, color: Colors.grey, size: 30),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "No upcoming classes scheduled. Book a session with an expert to see your reminders here!",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final sessions = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index].data();
                    final mentorName = session['mentorName'] ?? 'Mentor';
                    final topic = session['topic'] ?? 'General Mentorship';
                    final date = session['date'] ?? '';
                    final time = session['time'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  topic,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF333697),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: const Text(
                                    "Reminder Set ⏰",
                                    style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text("With Mentor: $mentorName", style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            Text("Scheduled for: $date at $time", style: TextStyle(fontSize: 14, color: Colors.grey[700])),
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
      ),
    );
  }
}