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
  final SchedulingService _schedulingService = SchedulingService();

  bool _isEditing = false;
  bool _isLoading = false;

  final TextEditingController _legalNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  DateTime? _dateOfBirth;

  String _selectedGender = 'Male';
  String _selectedCountry = 'Nigeria';
  List<String> _enrolledCourses = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _legalNameController.text =
              data['legalName'] ?? data['name'] ?? user?.displayName ?? '';
          _phoneController.text = data['phone'] ?? '';
          if (data['dateOfBirth'] != null) {
            _dateOfBirth = DateTime.tryParse(data['dateOfBirth']);
          }
          _selectedGender = data['gender'] ?? 'Male';
          _selectedCountry = data['country'] ?? 'Nigeria';
          _enrolledCourses = List<String>.from(data['enrolledCourses'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (user == null) return;
    if (_legalNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please enter your legal name for certificate issuance.",
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dobString = _dateOfBirth != null
          ? "${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}"
          : null;

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': _legalNameController.text.trim(),
        'legalName': _legalNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dateOfBirth': dobString,
        'gender': _selectedGender,
        'country': _selectedCountry,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Profile details saved! Your name and DOB are certified.",
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update profile: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);
    final dobDisplay = _dateOfBirth != null
        ? "${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}"
        : "Not Set";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Student Certification Profile"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            tooltip: _isEditing ? "Cancel" : "Edit Profile",
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: primaryColor,
                        child: Icon(
                          Icons.school,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _legalNameController.text.isEmpty
                                  ? (user?.displayName ?? "Mentee Scholar")
                                  : _legalNameController.text,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? "",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: const Text(
                                "Verified Learner Account",
                                style: TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Display DOB & Legal Name note
                  if (!_isEditing) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Date of Birth (DOB):",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        Text(
                          dobDisplay,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Country of Residence:",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        Text(
                          _selectedCountry,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Editable fields
                  if (_isEditing) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _legalNameController,
                      decoration: const InputDecoration(
                        labelText: "Legal Full Name (For Certificates)",
                        hintText: "As it appears on government ID",
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: const Icon(
                        Icons.cake_outlined,
                        color: primaryColor,
                      ),
                      title: Text(
                        _dateOfBirth == null
                            ? "Select Date of Birth (DOB)"
                            : "DOB: $dobDisplay",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                        color: primaryColor,
                        size: 20,
                      ),
                      onTap: _pickDateOfBirth,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCountry,
                      decoration: const InputDecoration(
                        labelText: "Country / Region",
                        prefixIcon: Icon(Icons.public),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      items:
                          [
                                'Nigeria',
                                'Ghana',
                                'Kenya',
                                'South Africa',
                                'United Kingdom',
                                'United States',
                                'Canada',
                                'Germany',
                                'Other',
                              ]
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCountry = val!),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Save Certified Details",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Enrolled Tracks Section
            const Text(
              "Enrolled Learning Tracks",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            if (_enrolledCourses.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  "No enrolled courses found yet. Select courses from the catalog to begin learning.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _enrolledCourses.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c,
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 28),

            // Class Reminders & Schedule Section
            const Row(
              children: [
                Icon(Icons.calendar_today, color: primaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  "Agreed Class Schedules & Reminders",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: user != null
                  ? _schedulingService.getMenteeUpcomingClasses(user!.uid)
                  : null,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sessions = snapshot.data?.docs ?? [];

                if (sessions.isEmpty) {
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: Colors.grey,
                            size: 30,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "No classes scheduled with mentors yet. Discuss with your mentor to lock in your class schedule!",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index].data();
                    final mentorName = session['mentorName'] ?? 'Mentor';
                    final courseTitle =
                        session['courseTitle'] ??
                        session['topic'] ??
                        'Mentorship Class';
                    final date = session['date'] ?? '';
                    final time = session['time'] ?? '';
                    final days = session['days'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    courseTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                  child: const Text(
                                    "Active Reminder ⏰",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Mentor: $mentorName",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              days.isNotEmpty
                                  ? "Class Days: $days at $time"
                                  : "Date: $date at $time",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
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

            const SizedBox(height: 28),

            // Earned Platform Certificates Section
            const Row(
              children: [
                Icon(Icons.workspace_premium, color: Colors.amber, size: 22),
                SizedBox(width: 8),
                Text(
                  "Earned Certificates",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: user != null
                  ? FirebaseFirestore.instance
                        .collection('certificates')
                        .where('menteeEmail', isEqualTo: user!.email)
                        .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: Colors.grey.shade400,
                          size: 30,
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            "Complete your classes to earn your official platform certificate with your legal name and DOB.",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final certs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: certs.length,
                  itemBuilder: (context, index) {
                    final data = certs[index].data() as Map<String, dynamic>;
                    final courseName = data['courseName'] ?? 'Tech Program';
                    final credentialId = data['credentialId'] ?? 'ML-CERT';

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.verified,
                          color: Colors.amber,
                          size: 32,
                        ),
                        title: Text(
                          courseName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Credential: $credentialId"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
