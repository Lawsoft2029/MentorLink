// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/dart.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 

class LiveSessionScreen extends StatefulWidget {
  final String sessionId; // UPDATED: Added to match mentor configuration parameters
  final String role;      // UPDATED: Added to track user role ('mentee' / 'mentor')
  final double ratePerSecond = 0.10 / 60;
  
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

  late RtcEngine _engine;
  bool _isCodeView = false;
  bool _isScreenSharing = false;
  bool _isReady = false;

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
    _initAgora();
    _startSession();
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

  // --- AUTOMATED PROJECT LOGIC ---
  Future<void> _handleExternalProject() async {
    String projectLink = "https://github.com/MentorLinks/session_share_active";

    setState(() {
      _messages.add({
        "user": "System",
        "text": "Live Share Requested. Access Code: $projectLink",
      });
    });

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Link shared to Mentor. Open VS Code to start collaborating.",
          ),
          backgroundColor: Color(0xFF333697),
        ),
      );
      return;
    }

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        if (!_isScreenSharing) await _toggleScreenSharing();
        final Uri vscodeUri = Uri.parse('vscode://file/$selectedDirectory');
        if (await canLaunchUrl(vscodeUri)) {
          await launchUrl(vscodeUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint("External project error: $e");
    }
  }

  Future<void> _initAgora() async {
    if (kIsWeb) {
      debugPrint("Agora Web running in Offline-UI mode.");
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
          onError: (ErrorCodeType err, String msg) {
            debugPrint("Agora Error: $msg");
          },
        ),
      );

      await _engine.enableVideo();
      await _engine.startPreview();
      await _engine.joinChannel(
        token: "YOUR_TOKEN",
        channelId: widget.sessionId, // UPDATED: Use sessionId as the live channel name
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint("Agora Init Failed: $e");
    }
  }

  Future<void> _toggleScreenSharing() async {
    if (kIsWeb) return;

    if (!_isScreenSharing) {
      await _engine.startScreenCapture(
        const ScreenCaptureParameters2(captureAudio: true, captureVideo: true),
      );
      setState(() {
        _isScreenSharing = true;
        _isCodeView = true;
      });
    } else {
      await _engine.stopScreenCapture();
      setState(() {
        _isScreenSharing = false;
        _isCodeView = false;
      });
    }
  }

  void _startSession() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      
      if (uid != null) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
        
        try {
          final docSnapshot = await userDoc.get();
          if (docSnapshot.exists) {
            final data = docSnapshot.data() as Map<String, dynamic>;
            double currentBalance = (data['walletBalanceUSD'] ?? 0.0).toDouble();
            String tier = data['userTier'] ?? 'Freemium';

            if (tier == 'Freemium' && currentBalance <= 0.0) {
              _timer?.cancel();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text("Session closed automatically: Insufficient Balance!"),
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
              return;
            }

            if (mounted) {
              setState(() {
                _seconds++;
                _totalCost += widget.ratePerSecond;
              });
            }

            if (tier == 'Freemium') {
              await userDoc.update({
                'walletBalanceUSD': FieldValue.increment(-widget.ratePerSecond),
                'totalMinutesLearned': FieldValue.increment(1 / 60),
              });
            } else {
              await userDoc.update({
                'totalMinutesLearned': FieldValue.increment(1 / 60),
              });
            }
          }
        } catch (e) {
          debugPrint("Operational background sync failed: $e");
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _chatController.dispose();
    if (!kIsWeb) {
      _engine.leaveChannel();
      _engine.release();
    }
    super.dispose();
  }

  void _verifyDebugSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Exit"),
        content: const Text("Save progress and end session?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () async {
              await _saveFilesLocally();
              if (!mounted) return;
              Navigator.pop(context);

              setState(() {
                _timer?.cancel();
                _seconds = 0;
              });
            },
            child: const Text("Yes"),
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
            const SizedBox(height: 20),
            _buildTopBar(),
            const SizedBox(height: 10),
            Expanded(
              child: _isCodeView ? _buildCodeEditor() : _buildVideoArea(),
            ),
            _buildMoneyMeter(),
            const SizedBox(height: 20),
            _buildControlBar(),
            const SizedBox(height: 30),
          ],
        ),
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
              if (_isCodeView)
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
    );
  }

  Widget _buildVideoArea() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _isReady
          ? (kIsWeb
              ? const Center(
                  child: Text(
                    "Agora Web Preview Active",
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ))
          : const Center(
              child: Icon(Icons.person, size: 80, color: Colors.white24),
            ),
    );
  }

  Widget _buildCodeEditor() {
    return Container(
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        // ignore: deprecated_member_use
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
        const Text("SESSION ACCRUED COST", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(
          "\$${_totalCost.toStringAsFixed(4)}",
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 24,
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
        _callAction(Icons.mic, Colors.white24),
        _callAction(
          Icons.laptop_windows,
          const Color(0xFF333697),
          onTap: _handleExternalProject,
        ),
        _callAction(Icons.chat, Colors.blueAccent, onTap: _showChatSheet),
        _callAction(
          _isCodeView ? Icons.videocam : Icons.code,
          _isCodeView ? Colors.orange : Colors.white24,
          onTap: () => setState(() => _isCodeView = !_isCodeView),
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
        radius: 28,
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}