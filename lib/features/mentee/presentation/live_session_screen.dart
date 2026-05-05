import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/dart.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:path_provider/path_provider.dart';

class LiveSessionScreen extends StatefulWidget {
  final double ratePerSecond = 0.50;
  const LiveSessionScreen({super.key});

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _seconds = 0;
  double _totalCost = 0.0;
  Timer? _timer;

  late RtcEngine _engine;
  final bool _isRecording = false; 
  bool _isCodeView = false;
  bool _isScreenSharing = false;
  bool _isReady = false;

  Map<String, String> _sessionFiles = {
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (fileNameController.text.isNotEmpty) {
                setState(() {
                  _sessionFiles[fileNameController.text] = "// Start coding...\n";
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

  // --- AGORA & PROJECT LOGIC (OMITTED FOR BREVITY - SAME AS BEFORE) ---
  Future<void> _handleExternalProject() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      if (!_isScreenSharing) await _toggleScreenSharing();
      final Uri vscodeUri = Uri.parse('vscode://file/$selectedDirectory');
      if (await canLaunchUrl(vscodeUri)) {
        await launchUrl(vscodeUri);
      } else {
        await Clipboard.setData(ClipboardData(text: selectedDirectory));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Path copied!")),
          );
        }
      }
    }
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: "YOUR_AGORA_APP_ID",
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        if (mounted) setState(() => _isReady = true);
      },
    ));
    await _engine.enableVideo();
    await _engine.startPreview();
    await _engine.joinChannel(token: "YOUR_TOKEN", channelId: "MentorSession_1", uid: 0, options: const ChannelMediaOptions(clientRoleType: ClientRoleType.clientRoleBroadcaster));
  }

  Future<void> _toggleScreenSharing() async {
    if (!_isScreenSharing) {
      await _engine.startScreenCapture(const ScreenCaptureParameters2(captureAudio: true, captureVideo: true));
      setState(() { _isScreenSharing = true; _isCodeView = true; });
    } else {
      await _engine.stopScreenCapture();
      setState(() { _isScreenSharing = false; _isCodeView = false; });
    }
  }

  void _startSession() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() { _seconds++; _totalCost += widget.ratePerSecond; });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  void _verifyDebugSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Exit"),
        content: const Text("Save progress and end session?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
          TextButton(onPressed: () async { await _saveFilesLocally(); Navigator.pop(context); Navigator.pop(context); }, child: const Text("Yes")),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Assigned the key to control the drawer
      backgroundColor: const Color(0xFF1A1A2E),
      drawer: _buildProjectSidebar(), // Sidebar added here
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildTopBar(),
            const SizedBox(height: 10),
            Expanded(child: _isCodeView ? _buildCodeEditor() : _buildVideoArea()),
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
            child: Center(child: Text("PROJECT FILES", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: ListView(
              children: _sessionFiles.keys.map((fileName) {
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file, color: Colors.white70, size: 18),
                  title: Text(fileName, style: TextStyle(color: _activeFile == fileName ? Colors.greenAccent : Colors.white)),
                  onTap: () {
                    _switchFile(fileName);
                    Navigator.pop(context); // Close drawer after selection
                  },
                );
              }).toList(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.greenAccent),
            title: const Text("Add New File", style: TextStyle(color: Colors.greenAccent)),
            onTap: () {
              Navigator.pop(context);
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
              Text("Live Session", style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          Text(
            "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
      child: _isReady ? AgoraVideoView(controller: VideoViewController(rtcEngine: _engine, canvas: const VideoCanvas(uid: 0))) : const Icon(Icons.person, size: 80, color: Colors.white24),
    );
  }

  Widget _buildCodeEditor() {
    return Container(
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Editing: $_activeFile", style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(
            child: CodeTheme(
              data: const CodeThemeData(styles: monokaiSublimeTheme),
              child: CodeField(
                controller: _codeController,
                textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14),
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
        const Text("COST", style: TextStyle(color: Colors.grey, fontSize: 10)),
        Text("₦${_totalCost.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildControlBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _callAction(Icons.mic, Colors.white24),
        _callAction(Icons.laptop_windows, const Color(0xFF333697), onTap: _handleExternalProject),
        _callAction(_isCodeView ? Icons.videocam : Icons.code, _isCodeView ? Colors.orange : Colors.white24, onTap: () => setState(() => _isCodeView = !_isCodeView)),
        _callAction(Icons.call_end, Colors.redAccent, onTap: _verifyDebugSuccess),
      ],
    );
  }

  Widget _callAction(IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: CircleAvatar(radius: 28, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 24)),
    );
  }
}