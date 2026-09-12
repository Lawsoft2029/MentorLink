import 'package:flutter/material.dart';
import '../../../core/services/scheduling_service.dart';

class BookSessionScreen extends StatefulWidget {
  final String mentorId;
  final String mentorName;

  const BookSessionScreen({
    super.key,
    required this.mentorId,
    required this.mentorName,
  });

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  final SchedulingService _schedulingService = SchedulingService();
  final TextEditingController _topicController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _confirmBooking() async {
    if (_topicController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all session details, date, and time."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _schedulingService.bookSession(
        mentorId: widget.mentorId,
        mentorName: widget.mentorName,
        selectedDate: _selectedDate!,
        selectedTime: _selectedTime!,
        topic: _topicController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session booked successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Booking failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Book Session with ${widget.mentorName}"),
        backgroundColor: const Color(0xFF333697),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: "Session Topic / Questions",
                hintText: "e.g., Code review for Flutter state management",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                _selectedDate == null
                    ? "Select Date"
                    : "Date: ${_selectedDate!.toLocal().toString().split(' ')[0]}",
              ),
              trailing: const Icon(
                Icons.calendar_today,
                color: Color(0xFF333697),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                _selectedTime == null
                    ? "Select Time"
                    : "Time: ${_selectedTime!.format(context)}",
              ),
              trailing: const Icon(Icons.access_time, color: Color(0xFF333697)),
              onTap: _pickTime,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333697),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Confirm & Book Session",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
