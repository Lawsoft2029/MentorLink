// ignore_for_file: prefer_final_fields, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/dart.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mentorlinks_app_project/features/chat/presentation/mentor_review_dialog.dart';

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

  // --- AGORA VIDEO VARIABLES ---
  late RtcEngine _engine;
  bool _isReady = false;
  int? _remoteUid;
  bool _muted = false;
  bool _camEnabled = true;

  // --- CHAT LOGIC ---
  final List<Map<String, String>> _messages = [];
  final TextEditingController _chatController = TextEditingController();

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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _userTier = userDoc.data()?['userTier'] ?? 'Freemium';
        });
      }

      // Load local offline notes backup
      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/MentorLinks/Notes/${widget.sessionId}_$uid.txt');
        if (await file.exists()) {
          final localContent = await file.readAsString();
          if (_notesController.text.isEmpty) {
            _notesController.text = localContent;
          }
        }
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
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final notesDir = Directory('${directory.path}/MentorLinks/Notes');
      if (!await notesDir.exists()) {
        await notesDir.create(recursive: true);
      }

      final file = File('${notesDir.path}/${widget.sessionId}_$uid.txt');
      await file.writeAsString(content);
    } catch (e) {
      debugPrint("Local notes save error: $e");
    }
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

    try {
      final directory = await getApplicationDocumentsDirectory();
      final sessionPath = '${directory.path}/MentorLinks/Session_Backup';
      final sessionDir = Directory(sessionPath);

      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
      }

      _sessionFiles[_activeFile] = _codeController.text;

      for (var entry in _sessionFiles.entries) {
        final file = File('$sessionPath/${entry.key}');
        await file.writeAsString(entry.value);
      }
    } catch (e) {
      debugPrint("Error saving files: $e");
    }
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

  // --- CHAT OVERLAY ---
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
                    child: ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(
                          _messages[index]['user']!,
                          style: TextStyle(
                            color: _messages[index]['user'] == "System"
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: Text(
                          _messages[index]['text']!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
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
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.greenAccent,
                          ),
                          onPressed: () {
                            if (_chatController.text.isNotEmpty) {
                              setModalState(() {
                                _messages.add({
                                  "user": "Me",
                                  "text": _chatController.text,
                                });
                                _chatController.clear();
                              });
                              setState(() {});
                            }
                          },
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
          onUserOffline: (
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
            
            double availableMinutes = userTier == 'Premium' || userTier == 'Enterprise'
                ? (data['monthlyPackageMinutes'] ?? 0.0).toDouble() 
                : (data['walletMinutes'] ?? 0.0).toDouble();

            if (availableMinutes <= 0.0) {
              _timer?.cancel();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text(
                      "Session closed: Your balance is empty! Upgrade or watch ads to continue.",
                    ),
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
              return;
            }

            if (mounted) {
              setState(() {
                _seconds++;
                _totalCost += (widget.ratePerMinute / 60); 
              });
            }

            if (userTier == 'Premium' || userTier == 'Enterprise') {
              await userDoc.update({
                'monthlyPackageMinutes': FieldValue.increment(-1 / 60),
                'totalMinutesLearned': FieldValue.increment(1 / 60),
              });
            } else {
              await userDoc.update({
                'walletMinutes': FieldValue.increment(-1 / 60),
                'totalMinutesLearned': FieldValue.increment(1 / 60),
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

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _chatController.dispose();
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
        title: const Text("Confirm Exit", style: TextStyle(color: Colors.white)),
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
              if (exactMinutesSpent < (1/60) && _seconds > 0) exactMinutesSpent = 1/60;

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
                final mentorUid = sessionData['mentorId'] ?? sessionData['mentorUid'];
                final studentUid = sessionData['studentId'] ?? FirebaseAuth.instance.currentUser?.uid;

                final batch = FirebaseFirestore.instance.batch();

                final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId);
                batch.set(sessionRef, {
                  'minutesSpent': exactMinutesSpent,
                  'finalCostUSD': totalGrossCost,
                  'mentorEarningsUSD': mentorEarnings,
                  'platformRevenueUSD': platformRevenue,
                  'endedAt': FieldValue.serverTimestamp(),
                  'status': 'Completed',
                }, SetOptions(merge: true));

                if (mentorUid != null) {
                  final mentorRef = FirebaseFirestore.instance.collection('users').doc(mentorUid);
                  batch.update(mentorRef, {
                    'mentorEarningsUSD': FieldValue.increment(mentorEarnings),
                  });
                }

                final revenueRef = FirebaseFirestore.instance.collection('platform_revenue').doc();
                batch.set(revenueRef, {
                  'sessionId': widget.sessionId,
                  'amountEarned': platformRevenue,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (studentUid != null && widget.role == 'mentee') {
                  final studentRef = FirebaseFirestore.instance.collection('users').doc(studentUid);
                  final studentSnap = await studentRef.get();
                  if (studentSnap.exists) {
                    String userTier = studentSnap.data()?['userTier'] ?? 'Freemium';
                    if (userTier == 'Premium' || userTier == 'Enterprise') {
                      batch.update(studentRef, {
                        'monthlyPackageMinutes': FieldValue.increment(-exactMinutesSpent),
                      });
                    } else {
                      batch.update(studentRef, {
                        'walletMinutes': FieldValue.increment(-exactMinutesSpent),
                      });
                    }
                  }
                }

                // Log Recording Vault Entry for Premium/Enterprise/Mentor
                if (studentUid != null && (widget.role == 'mentor' || _userTier == 'Premium' || _userTier == 'Enterprise')) {
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
                    'storagePath': _localRecordingPath ?? '/MentorLinks/Recordings/${widget.sessionId}.mp4',
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
            child: const Text("Yes", style: TextStyle(color: Colors.greenAccent)),
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
                            child: _isReady && _camEnabled && !kIsWeb
                                ? AgoraVideoView(
                                    controller: VideoViewController(
                                      rtcEngine: _engine,
                                      canvas: const VideoCanvas(uid: 0),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons.videocam_off,
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
    bool isAllowed = widget.role == 'mentor' || 
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
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                      style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      _isSyncedToCloud ? Icons.cloud_done : Icons.cloud_upload_outlined,
                      color: _isSyncedToCloud ? Colors.greenAccent : Colors.orangeAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSyncedToCloud ? "Synced" : "Saving...",
                      style: TextStyle(
                        color: _isSyncedToCloud ? Colors.greenAccent : Colors.orangeAccent,
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
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                decoration: const InputDecoration(
                  hintText: "Type key class notes, algorithms, or debugging steps here... (Saves offline automatically)",
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              _isRecording = recordingNow; // Syncs recording pause state with session pause
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
        // --- Notepad Toggle Button ---
        _callAction(
          Icons.edit_note,
          _isNotesView ? Colors.blue : Colors.white24,
          onTap: () => setState(() {
            _isNotesView = !_isNotesView;
            if (_isNotesView) _isCodeView = false;
          }),
        ),
        _callAction(Icons.chat, Colors.blueAccent, onTap: _showChatSheet),
        // --- Code Editor Toggle Button ---
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