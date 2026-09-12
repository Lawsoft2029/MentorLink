import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/scheduling_service.dart';
import '../../../core/services/class_reminder_service.dart';

class MentorScheduleSetupScreen extends StatefulWidget {
  final String menteeId;
  final String menteeName;
  final String? menteeEmail;
  final String courseTitle;

  const MentorScheduleSetupScreen({
    super.key,
    required this.menteeId,
    required this.menteeName,
    this.menteeEmail,
    required this.courseTitle,
  });

  @override
  State<MentorScheduleSetupScreen> createState() =>
      _MentorScheduleSetupScreenState();
}

class _MentorScheduleSetupScreenState extends State<MentorScheduleSetupScreen> {
  final SchedulingService _schedulingService = SchedulingService();
  final ClassReminderService _reminderService = ClassReminderService();

  final List<String> _daysList = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final Set<String> _selectedDays = {'Monday', 'Wednesday'};
  TimeOfDay _selectedTime = const TimeOfDay(hour: 16, minute: 0);
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  int _frequencyPerWeek = 2;
  int _totalSessions = 8;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _submitClassSchedule() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one day for class."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    final mentorId = currentUser?.uid ?? 'sample_mentor_id';
    final mentorName =
        currentUser?.displayName ?? currentUser?.email ?? 'Mentor';

    final String timeFormatted =
        "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";

    try {
      await _schedulingService.createMentorSchedule(
        mentorId: mentorId,
        mentorName: mentorName,
        menteeId: widget.menteeId,
        menteeName: widget.menteeName,
        menteeEmail:
            widget.menteeEmail ??
            '${widget.menteeName.toLowerCase().replaceAll(' ', '')}@gmail.com',
        courseTitle: widget.courseTitle,
        daysOfWeek: _selectedDays.toList(),
        timeOfDayString: timeFormatted,
        frequencyPerWeek: _frequencyPerWeek,
        totalSessions: _totalSessions,
        startDate: _startDate,
        additionalNotes: _notesController.text.trim(),
      );

      // Trigger local alert
      await _reminderService.showClassAlert(
        title: "Class Schedule Confirmed!",
        body:
            "Class with ${widget.menteeName} on ${_selectedDays.join(', ')} at $timeFormatted.",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Class schedule created & synced to mentee profile!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to create schedule: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Class Schedule"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student & Course Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: primaryColor,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Student: ${widget.menteeName}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Course: ${widget.courseTitle}",
                          style: const TextStyle(
                            color: primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1. Select Class Days
            const Text(
              "Class Days (Select all that apply)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _daysList.map((day) {
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  selectedColor: primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(day);
                      } else {
                        if (_selectedDays.length > 1) {
                          _selectedDays.remove(day);
                        }
                      }
                      _frequencyPerWeek = _selectedDays.length;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 2. Class Time Picker
            const Text(
              "Class Time",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.access_time, color: primaryColor),
              title: Text(
                _selectedTime.format(context),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text("Tap to change daily class time"),
              trailing: const Icon(Icons.edit, color: primaryColor),
              onTap: _pickTime,
            ),
            const SizedBox(height: 24),

            // 3. Start Date Picker
            const Text(
              "First Class Start Date",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.calendar_today, color: primaryColor),
              title: Text(
                "${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text("Tap to select launch date"),
              trailing: const Icon(Icons.edit, color: primaryColor),
              onTap: _pickStartDate,
            ),
            const SizedBox(height: 24),

            // 4. Frequency & Total Sessions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Times Per Week",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _frequencyPerWeek,
                            isExpanded: true,
                            items: [1, 2, 3, 4, 5].map((val) {
                              return DropdownMenuItem(
                                value: val,
                                child: Text("$val x per week"),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _frequencyPerWeek = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Sessions",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _totalSessions,
                            isExpanded: true,
                            items: [4, 8, 12, 16, 24].map((val) {
                              return DropdownMenuItem(
                                value: val,
                                child: Text("$val classes"),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _totalSessions = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 5. Additional Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: "Curriculum / Syllabus Notes (Optional)",
                hintText:
                    "e.g., Week 1: Dart Fundamentals, Week 2: Riverpod state",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _submitClassSchedule,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save & Notify Mentee Schedule",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
