import 'package:flutter/material.dart';

class LiveSessionScreen extends StatefulWidget {
  final String sessionId; // The Firestore document ID both users are watching
  final String role;      // Expects either 'mentor' or 'mentee'

  const LiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.role,
  });

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  // We will initialize our text controllers and state properties here in the next steps

  @override
  Widget build(BuildContext context) {
    // The accent color shifts depending on who is looking at the screen
    final Color sessionColor = widget.role == 'mentor' 
        ? const Color(0xFF00796B)  // Premium Educator Teal
        : const Color(0xFF333697); // Learner Indigo

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.role == 'mentor' ? 'Expert Workspace Panel' : 'Mentee Classroom Container'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false, // Forces users to use the explicit "End Session" button
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, color: sessionColor, size: 64),
            const SizedBox(height: 16),
            Text(
              "Active Session: ${widget.sessionId}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Current Viewport Permission: ${widget.role.toUpperCase()}",
              style: TextStyle(color: sessionColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}