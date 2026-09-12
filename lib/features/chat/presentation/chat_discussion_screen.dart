import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../scheduling/presentation/mentor_schedule_setup_screen.dart';

class ChatDiscussionScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String courseTitle;

  const ChatDiscussionScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.courseTitle,
  });

  @override
  State<ChatDiscussionScreen> createState() => _ChatDiscussionScreenState();
}

class _ChatDiscussionScreenState extends State<ChatDiscussionScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentUserRole = 'mentee';

  String get _chatRoomId {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    List<String> ids = [currentUserId, widget.recipientId];
    ids.sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _currentUserRole = doc.data()?['role'] ?? 'mentee';
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _messageController.text.trim();
    if (text.isEmpty) return;

    if (presetText == null) _messageController.clear();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(_chatRoomId)
        .collection('messages')
        .add({
          'senderId': currentUserId,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
        });

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(_chatRoomId)
        .set({
          'participants': [currentUserId, widget.recipientId],
          'lastMessage': text,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'courseContext': widget.courseTitle,
        }, SetOptions(merge: true));
  }

  void _openScheduleDialog() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MentorScheduleSetupScreen(
          menteeId: _currentUserRole == 'mentor'
              ? widget.recipientId
              : FirebaseAuth.instance.currentUser!.uid,
          menteeName: _currentUserRole == 'mentor'
              ? widget.recipientName
              : (FirebaseAuth.instance.currentUser?.displayName ??
                    'Student Learner'),
          courseTitle: widget.courseTitle,
        ),
      ),
    );

    if (result == true) {
      _sendMessage(
        "📅 Class Schedule Confirmed: I have officially scheduled our upcoming ${widget.courseTitle} sessions! Both our profiles have been updated.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF333697);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.recipientName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "Track: ${widget.courseTitle}",
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          // Step 4 Action: Set Class Schedule
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _openScheduleDialog,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.event_note, size: 16, color: Colors.white),
              label: const Text(
                "Set Schedule",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Helpful Coordination Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: primaryColor.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Discuss times with ${widget.recipientName}. Then tap 'Set Schedule' to lock in class days and set reminders.",
                    style: const TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Start the discussion with ${widget.recipientName} regarding how you want classes to be held.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              _sendMessage(
                                "Hello ${widget.recipientName}! I would like to discuss our schedule and timing for the ${widget.courseTitle} course.",
                              );
                            },
                            icon: const Icon(Icons.waving_hand, size: 16),
                            label: const Text("Say Hello"),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final senderId = data['senderId'];
                    final text = data['text'] ?? '';
                    final isMe = senderId == currentUserId;
                    final isSystemNotice = text.startsWith("📅");

                    if (isSystemNotice) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(16),
                            bottomLeft: !isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message input bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.calendar_month, color: primaryColor),
                  tooltip: "Set Schedule",
                  onPressed: _openScheduleDialog,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Discuss schedule, class days, or topics...",
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: primaryColor,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
