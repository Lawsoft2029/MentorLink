import 'package:flutter/material.dart';

class VirtualClassroomScreen extends StatefulWidget {
  final String roomName;
  final String participantName;

  const VirtualClassroomScreen({
    super.key,
    required this.roomName,
    required this.participantName,
  });

  @override
  State<VirtualClassroomScreen> createState() => _VirtualClassroomScreenState();
}

class _VirtualClassroomScreenState extends State<VirtualClassroomScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isScreenSharing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Classroom: ${widget.roomName}"),
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("End-to-end encrypted mentoring room active.")),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Video Feed Simulation Grid
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333697),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      widget.participantName.isNotEmpty ? widget.participantName[0].toUpperCase() : "M",
                      style: const TextStyle(fontSize: 50, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.participantName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Connected via MentorLinks Secure Video Relay",
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),

          // Floating Self-View Simulation Box (Top Right)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white54, size: 40),
              ),
            ),
          ),

          // Bottom Control Toolbar
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mute Mic Button
                FloatingActionButton(
                  heroTag: "mute",
                  backgroundColor: _isMuted ? Colors.red : Colors.grey[800],
                  onPressed: () => setState(() => _isMuted = !_isMuted),
                  child: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                ),
                const SizedBox(width: 16),

                // Toggle Video Button
                FloatingActionButton(
                  heroTag: "video",
                  backgroundColor: _isVideoOff ? Colors.red : Colors.grey[800],
                  onPressed: () => setState(() => _isVideoOff = !_isVideoOff),
                  child: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam, color: Colors.white),
                ),
                const SizedBox(width: 16),

                // Screen Share Button
                FloatingActionButton(
                  heroTag: "screen",
                  backgroundColor: _isScreenSharing ? Colors.teal : Colors.grey[800],
                  onPressed: () => setState(() => _isScreenSharing = !_isScreenSharing),
                  child: Icon(_isScreenSharing ? Icons.screen_share : Icons.stop_screen_share, color: Colors.white),
                ),
                const SizedBox(width: 16),

                // End Call Button
                FloatingActionButton(
                  heroTag: "end_call",
                  backgroundColor: Colors.redAccent,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}