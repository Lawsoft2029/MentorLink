// ignore_for_file: prefer_final_fields, curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/dart.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mentorlinks_app_project/features/chat/presentation/mentor_review_dialog.dart';
import 'package:mentorlinks_app_project/features/gamification/presentation/unlock_study_time_screen.dart';

class LiveSessionScreen extends StatefulWidget {
  final String sessionId;
  final String role; // 'mentee' or 'mentor'
  final double ratePerMinute = 0.10; // $0.10 gross rate per minute

  const LiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.role,
  });

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _seconds = 0;
  double _totalCost = 0.0;
  Timer? _timer;
  bool _isPaused = false;

  // --- WORKSPACE VIEW MODES ---
  bool _isCodeView = false;
  bool _isNotesView = false; // Toggle for Notepad

  // --- NOTEPAD STATE VARIABLES ---
  final TextEditingController _notesController = TextEditingController();
  Timer? _notesDebounceTimer;
  bool _isSyncedToCloud = true;
  String _userTier = 'Freemium';

  // --- RECORDING STATE VARIABLES ---
  bool _isRecording = true;
  String? _localRecordingPath;

  // --- AGORA VIDEO & SCREEN SHARE VARIABLES ---
  late RtcEngine _engine;
  bool _isReady = false;
  int? _remoteUid;
  bool _muted = false;
  bool _isScreenSharing = false; // Tracks live screen share state

  // --- CHAT LOGIC ---
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  final Map<String, String> _sessionFiles = {
    "main.dart": "void main() {\n  runApp(const MyApp());\n}",
  };
  String _activeFile = "main.dart";
  late CodeController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      text: _sessionFiles[_activeFile],
      language: dart,
    );
    _fetchUserTierAndNotes();
    _initAgora();
    _startSession();
    _notesController.addListener(_onNoteTextChanged);
  }

  // --- FETCH USER TIER & INITIALIZE NOTES ---
  Future<void> _fetchUserTierAndNotes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists && mounted) {
        setState(() {
          _userTier = userDoc.data()?['userTier'] ?? 'Freemium';
        });
      }

      // Load cloud notes backup
      final cloudDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('session_notes')
          .doc(widget.sessionId)
          .get();

      if (cloudDoc.exists && mounted) {
        final cloudText = cloudDoc.data()?['noteContent'] ?? '';
        if (cloudText.isNotEmpty && cloudText != _notesController.text) {
          _notesController.text = cloudText;
        }
      }
    } catch (e) {
      debugPrint("Error loading tier or notes: $e");
    }
  }

  // --- NOTEPAD SYNC LOGIC ---
  void _onNoteTextChanged() {
    setState(() => _isSyncedToCloud = false);
    _saveNotesLocally(_notesController.text);

    if (_notesDebounceTimer?.isActive ?? false) _notesDebounceTimer!.cancel();
    _notesDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _syncNotesToCloud(_notesController.text);
    });
  }

  Future<void> _saveNotesLocally(String content) async {
    if (kIsWeb) return;
  }

  Future<void> _syncNotesToCloud(String content) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('session_notes')
          .doc(widget.sessionId)
          .set({
            'sessionId': widget.sessionId,
            'noteContent': content,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isSyncedToCloud = true);
      }
    } catch (e) {
      debugPrint("Cloud sync pending (offline): $e");
    }
  }

  // --- PERSISTENCE LOGIC ---
  Future<void> _saveFilesLocally() async {
    if (kIsWeb) return;
    _sessionFiles[_activeFile] = _codeController.text;
  }

  // --- FILE MANAGEMENT ---
  void _createNewFile() {
    TextEditingController fileNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("New File", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: fileNameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "filename.dart",
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (fileNameController.text.isNotEmpty) {
                setState(() {
                  _sessionFiles[fileNameController.text] =
                      "// Start coding...\n";
                  _activeFile = fileNameController.text;
                  _codeController.text = _sessionFiles[_activeFile]!;
                });
                _saveFilesLocally();
              }
              Navigator.pop(context);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _switchFile(String fileName) {
    _saveFilesLocally();
    setState(() {
      _sessionFiles[_activeFile] = _codeController.text;
      _activeFile = fileName;
      _codeController.text = _sessionFiles[fileName]!;
    });
  }

  // --- UNIFIED CHAT OVERLAY CONNECTED TO FIRESTORE WITH TIMESTAMPS ---
  void _showChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          final String unifiedChatRoomId = "sample_mentor_mentee_room";

          void sendSessionMessage() async {
            if (_chatController.text.trim().isEmpty) return;
            final text = _chatController.text.trim();
            _chatController.clear();

            try {
              if (currentUserId != null) {
                await FirebaseFirestore.instance
                    .collection('chat_rooms')
                    .doc(unifiedChatRoomId)
                    .collection('messages')
                    .add({
                      'senderId': currentUserId,
                      'message': text,
                      'timestamp': FieldValue.serverTimestamp(),
                      'localTime': DateTime.now().millisecondsSinceEpoch,
                      'status': 'sent',
                    });
              }
            } catch (e) {
              debugPrint("Failed to send live chat message: $e");
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SizedBox(
              height: 400,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Session Chat",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('chat_rooms')
                          .doc(unifiedChatRoomId)
                          .collection('messages')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              "No messages yet. Say hello!",
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        docs.sort((a, b) {
                          final timeA = a.data()['localTime'] ?? 0;
                          final timeB = b.data()['localTime'] ?? 0;
                          return timeA.compareTo(timeB);
                        });

                        return ListView.builder(
                          controller: _chatScrollController,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final bool isMe = data['senderId'] == currentUserId;
                            final messageText = data['message'] ?? '';

                            String timeString = "";
                            if (data['localTime'] != null) {
                              final dateTime =
                                  DateTime.fromMillisecondsSinceEpoch(
                                    data['localTime'],
                                  );
                              timeString =
                                  "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
                            }

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF333697)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      messageText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (timeString.isNotEmpty) ...[
                                          Text(
                                            timeString,
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        const Text(
                                          "✓",
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Type a message...",
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => sendSessionMessage(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.greenAccent,
                          ),
                          onPressed: sendSessionMessage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _initAgora() async {
    if (kIsWeb) {
      if (mounted) setState(() => _isReady = true);
      return;
    }

    try {
      await [Permission.microphone, Permission.camera].request();
      _engine = createAgoraRtcEngine();
      await _engine.initialize(
        const RtcEngineContext(
          appId: "YOUR_AGORA_APP_ID",
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (mounted) setState(() => _isReady = true);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                setState(() {
                  _remoteUid = null;
                });
              },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("Agora Error: $msg");
          },
        ),
      );

      await _engine.enableVideo();
      await _engine.startPreview();
      await _engine.joinChannel(
        token: "YOUR_TOKEN",
        channelId: widget.sessionId,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint("Agora Init Failed: $e");
    }
  }

  void _onToggleMute() {
    setState(() {
      _muted = !_muted;
    });
    if (!kIsWeb) {
      _engine.muteLocalAudioStream(_muted);
    }
  }

  // --- SCREEN SHARE TOGGLE LOGIC ---
  Future<void> _onToggleScreenShare() async {
    setState(() {
      _isScreenSharing = !_isScreenSharing;
    });

    if (!kIsWeb) {
      try {
        if (_isScreenSharing) {
          // Starts broadcasting the entire screen/display to the mentor
          await _engine.startScreenCapture(
            const ScreenCaptureParameters2(
              captureAudio: true,
              audioParams: ScreenAudioParameters(
                sampleRate: 16000,
                channels: 2,
                captureSignalVolume: 100,
              ),
              captureVideo: true,
              videoParams: ScreenVideoParameters(
                dimensions: VideoDimensions(width: 1280, height: 720),
                frameRate: 15,
                bitrate: 1000,
              ),
            ),
          );

          await _engine.updateChannelMediaOptions(
            const ChannelMediaOptions(
              publishScreenCaptureVideo: true,
              publishScreenCaptureAudio: true,
              publishCameraTrack: false,
            ),
          );
        } else {
          // Stops screen capture and reverts back to normal camera/code view
          await _engine.stopScreenCapture();
          await _engine.updateChannelMediaOptions(
            const ChannelMediaOptions(
              publishScreenCaptureVideo: false,
              publishScreenCaptureAudio: false,
              publishCameraTrack: true,
            ),
          );
        }
      } catch (e) {
        debugPrint("Screen share error: $e");
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _isScreenSharing ? Colors.green : Colors.grey[800],
          content: Text(
            _isScreenSharing
                ? "Screen share started! Your mentor can now view your whole screen."
                : "Screen share stopped.",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- LIVE PER-MINUTE WALLET / PACKAGE DEDUCTION TIMER ---
  void _startSession() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isPaused) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      if (widget.role == 'mentee') {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

        try {
          final docSnapshot = await userDoc.get();
          if (docSnapshot.exists) {
            final data = docSnapshot.data() as Map<String, dynamic>;
            String userTier = data['userTier'] ?? 'Freemium';

            double availableMinutes =
                userTier == 'Premium' || userTier == 'Enterprise'
                ? (data['monthlyPackageMinutes'] ?? 0.0).toDouble()
                : (data['walletMinutes'] ?? 0.0).toDouble();

            if (availableMinutes <= 0.0) {
              _timer?.cancel();
              if (mounted) {
                _showTopUpOrAdModal(context);
              }
              return;
            }

            if (mounted) {
              setState(() {
                _seconds++;
                _totalCost += (widget.ratePerMinute / 60);
              });
            }
          }
        } catch (e) {
          debugPrint("Wallet deduction sync failed: $e");
        }
      } else {
        if (mounted) setState(() => _seconds++);
      }
    });
  }

  // --- PITCH-READY AD & TOP-UP MODAL ---
  void _showTopUpOrAdModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Study Wallet Empty! 🛑",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "Watch a quick ad or top-up your wallet to keep your live session going seamlessly.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[800],
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.slow_motion_video),
              label: const Text("Watch Ad & Earn +1 Hour (60 Mins)"),
              onPressed: () async {
                Navigator.pop(modalContext);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UnlockStudyTimeScreen(),
                  ),
                );
                if (mounted) {
                  _recheckWalletAndResumeSession();
                }
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(modalContext);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                "Return to Dashboard",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recheckWalletAndResumeSession() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await docRef.get();
      if (snap.exists && mounted) {
        final data = snap.data() ?? {};
        String userTier = data['userTier'] ?? 'Freemium';
        double availableMinutes =
            userTier == 'Premium' || userTier == 'Enterprise'
            ? (data['monthlyPackageMinutes'] ?? 0.0).toDouble()
            : (data['walletMinutes'] ?? 0.0).toDouble();

        if (availableMinutes > 0.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                "Ad completed successfully! +1 Hour study pass active.",
              ),
            ),
          );
          _startSession();
        } else {
          _showTopUpOrAdModal(context);
        }
      }
    } catch (e) {
      debugPrint("Error checking wallet: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _notesController.dispose();
    _notesDebounceTimer?.cancel();
    if (!kIsWeb) {
      _engine.leaveChannel();
      _engine.release();
    }
    super.dispose();
  }

  // --- REVENUE SPLIT & TUTOR PAYOUT SETTLEMENT ON EXIT ---
  void _verifyDebugSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          "Confirm Exit",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Do you want to end this class session? The mentor will be paid and startup revenue recorded.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () async {
              _timer?.cancel();
              await _saveFilesLocally();

              double exactMinutesSpent = _seconds / 60.0;
              if (exactMinutesSpent < (1 / 60) && _seconds > 0)
                exactMinutesSpent = 1 / 60;

              const double mentorShareRate = 0.80;
              const double platformShareRate = 0.20;

              double totalGrossCost = exactMinutesSpent * widget.ratePerMinute;
              double mentorEarnings = totalGrossCost * mentorShareRate;
              double platformRevenue = totalGrossCost * platformShareRate;

              try {
                final sessionDoc = await FirebaseFirestore.instance
                    .collection('sessions')
                    .doc(widget.sessionId)
                    .get();

                final sessionData = sessionDoc.data() ?? {};
                final mentorUid =
                    sessionData['mentorId'] ?? sessionData['mentorUid'];
                final studentUid =
                    sessionData['studentId'] ??
                    FirebaseAuth.instance.currentUser?.uid;

                final batch = FirebaseFirestore.instance.batch();

                final sessionRef = FirebaseFirestore.instance
                    .collection('sessions')
                    .doc(widget.sessionId);
                batch.set(sessionRef, {
                  'minutesSpent': exactMinutesSpent,
                  'finalCostUSD': totalGrossCost,
                  'mentorEarningsUSD': mentorEarnings,
                  'platformRevenueUSD': platformRevenue,
                  'endedAt': FieldValue.serverTimestamp(),
                  'status': 'Completed',
                }, SetOptions(merge: true));

                if (mentorUid != null) {
                  final mentorRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(mentorUid);
                  batch.update(mentorRef, {
                    'mentorEarningsUSD': FieldValue.increment(mentorEarnings),
                  });
                }

                final revenueRef = FirebaseFirestore.instance
                    .collection('platform_revenue')
                    .doc();
                batch.set(revenueRef, {
                  'sessionId': widget.sessionId,
                  'amountEarned': platformRevenue,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (studentUid != null && widget.role == 'mentee') {
                  final studentRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(studentUid);
                  final studentSnap = await studentRef.get();
                  if (studentSnap.exists) {
                    String userTier =
                        studentSnap.data()?['userTier'] ?? 'Freemium';
                    if (userTier == 'Premium' || userTier == 'Enterprise') {
                      batch.update(studentRef, {
                        'monthlyPackageMinutes': FieldValue.increment(
                          -exactMinutesSpent,
                        ),
                      });
                    } else {
                      batch.update(studentRef, {
                        'walletMinutes': FieldValue.increment(
                          -exactMinutesSpent,
                        ),
                      });
                    }
                  }
                }

                if (studentUid != null &&
                    (widget.role == 'mentor' ||
                        _userTier == 'Premium' ||
                        _userTier == 'Enterprise')) {
                  final recordingRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.role == 'mentor' ? mentorUid : studentUid)
                      .collection('session_recordings')
                      .doc(widget.sessionId);

                  batch.set(recordingRef, {
                    'sessionId': widget.sessionId,
                    'durationMinutes': exactMinutesSpent,
                    'recordedAt': FieldValue.serverTimestamp(),
                    'status': 'Saved',
                    'storagePath':
                        _localRecordingPath ??
                        '/MentorLinks/Recordings/${widget.sessionId}.mp4',
                  }, SetOptions(merge: true));
                }

                await batch.commit();

                if (!mounted) return;
                Navigator.pop(context);
                Navigator.of(context).popUntil((route) => route.isFirst);

                if (mentorUid != null && widget.role == 'mentee') {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => MentorReviewDialog(
                      mentorUid: mentorUid,
                      sessionId: widget.sessionId,
                    ),
                  );
                }
              } catch (e) {
                debugPrint("Error settling session payment: $e");
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text(
              "Yes",
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1A1A2E),
      drawer: _buildProjectSidebar(),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildTopBar(),
            const SizedBox(height: 10),

            // Dynamic Center Workspace Switcher
            if (_isNotesView)
              Expanded(child: _buildNotepadEditor())
            else if (_isCodeView)
              Expanded(child: _buildCodeEditor())
            else
              Container(
                height: 160,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: _remoteUid != null && !kIsWeb
                          ? AgoraVideoView(
                              controller: VideoViewController.remote(
                                rtcEngine: _engine,
                                canvas: VideoCanvas(uid: _remoteUid),
                                connection: RtcConnection(
                                  channelId: widget.sessionId,
                                ),
                              ),
                            )
                          : const Text(
                              'Waiting for participant to join...',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 80,
                          height: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _isReady && !kIsWeb
                                ? AgoraVideoView(
                                    controller: VideoViewController(
                                      rtcEngine: _engine,
                                      canvas: const VideoCanvas(uid: 0),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 10),
            _buildMoneyMeter(),
            const SizedBox(height: 10),
            _buildControlBar(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- CLOUD & OFFLINE NOTEPAD WIDGET ---
  Widget _buildNotepadEditor() {
    bool isAllowed =
        widget.role == 'mentor' ||
        _userTier == 'Premium' ||
        _userTier == 'Enterprise';

    if (!isAllowed) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 44, color: Colors.amber),
            const SizedBox(height: 12),
            const Text(
              "Notepad Locked to Premium / Enterprise",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Upgrade your subscription to unlock cloud/offline session notetaking.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.blueAccent, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "Session Cloud & Offline Notepad",
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      _isSyncedToCloud
                          ? Icons.cloud_done
                          : Icons.cloud_upload_outlined,
                      color: _isSyncedToCloud
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSyncedToCloud ? "Synced" : "Saving...",
                      style: TextStyle(
                        color: _isSyncedToCloud
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _notesController,
                maxLines: null,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  hintText:
                      "Type key class notes, algorithms, or debugging steps here... (Saves offline automatically)",
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSidebar() {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A2E),
      child: Column(
        children: [
          const DrawerHeader(
            child: Center(
              child: Text(
                "PROJECT FILES",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: _sessionFiles.keys.map((fileName) {
                return ListTile(
                  leading: const Icon(
                    Icons.insert_drive_file,
                    color: Colors.white70,
                    size: 18,
                  ),
                  title: Text(
                    fileName,
                    style: TextStyle(
                      color: _activeFile == fileName
                          ? Colors.greenAccent
                          : Colors.white,
                    ),
                  ),
                  onTap: () {
                    _switchFile(fileName);
                    _scaffoldKey.currentState?.closeDrawer();
                  },
                );
              }).toList(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.greenAccent),
            title: const Text(
              "Add New File",
              style: TextStyle(color: Colors.greenAccent),
            ),
            onTap: () {
              _scaffoldKey.currentState?.closeDrawer();
              _createNewFile();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.folder, color: Colors.greenAccent),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const Text(
                "Live Session",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          Row(
            children: [
              if (_isPaused)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "PAUSED",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditor() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Editing: $_activeFile",
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: CodeTheme(
              data: const CodeThemeData(styles: monokaiSublimeTheme),
              child: CodeField(
                controller: _codeController,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                expands: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyMeter() {
    return Column(
      children: [
        Text(
          _isPaused ? "SESSION PAUSED (NO CHARGE)" : "SESSION ACCRUED COST",
          style: TextStyle(
            color: _isPaused ? Colors.orangeAccent : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "\$${_totalCost.toStringAsFixed(4)}",
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildControlBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _callAction(
          _muted ? Icons.mic_off : Icons.mic,
          _muted ? Colors.red : Colors.white24,
          onTap: _onToggleMute,
        ),
        _callAction(
          _isPaused ? Icons.play_arrow : Icons.pause,
          _isPaused ? Colors.green : Colors.orange,
          onTap: () {
            final recordingNow = !_isPaused;
            setState(() {
              _isPaused = !_isPaused;
              _isRecording = recordingNow;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isRecording
                      ? "Class & Recording resumed."
                      : "Class & Recording paused. Billing halted.",
                ),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
        // --- NEW SCREEN SHARE BUTTON ---
        _callAction(
          _isScreenSharing ? Icons.screen_share : Icons.stop_screen_share,
          _isScreenSharing ? Colors.green : Colors.white24,
          onTap: _onToggleScreenShare,
        ),
        _callAction(
          Icons.edit_note,
          _isNotesView ? Colors.blue : Colors.white24,
          onTap: () => setState(() {
            _isNotesView = !_isNotesView;
            if (_isNotesView) _isCodeView = false;
          }),
        ),
        _callAction(Icons.chat, Colors.blueAccent, onTap: _showChatSheet),
        _callAction(
          _isCodeView ? Icons.videocam : Icons.code,
          _isCodeView ? Colors.orange : Colors.white24,
          onTap: () => setState(() {
            _isCodeView = !_isCodeView;
            if (_isCodeView) _isNotesView = false;
          }),
        ),
        _callAction(
          Icons.call_end,
          Colors.redAccent,
          onTap: _verifyDebugSuccess,
        ),
      ],
    );
  }

  Widget _callAction(IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: CircleAvatar(
        radius: 26,
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
