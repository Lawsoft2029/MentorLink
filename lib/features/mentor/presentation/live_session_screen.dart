import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LiveSessionScreen extends StatefulWidget {
  final String sessionId; 
  final String role;      

  const LiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.role,
  });

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  final _codeWorkspaceController = TextEditingController(); 
  
  Timer? _sessionClockTimer;
  Timer? _debounceTimer; 
  StreamSubscription<DocumentSnapshot>? _sessionDocumentSubscription; 
  
  int _secondsElapsed = 0;
  bool _isEnding = false; 
  bool _isLocalUpdate = false; 
  bool _isPaused = false; 

  // --- AGORA VIDEO VARIABLES ---
  late RtcEngine _engine;
  bool _isReady = false;
  int? _remoteUid;
  bool _muted = false;
  bool _camEnabled = true;

  @override
  void initState() {
    super.initState();
    _startSessionStopwatch();
    _listenForLiveSessionUpdates();
    _codeWorkspaceController.addListener(_onCodeTextChanged); 
    _initAgora();
  }

  @override
  void dispose() {
    _sessionClockTimer?.cancel();
    _debounceTimer?.cancel();
    _sessionDocumentSubscription?.cancel();
    _codeWorkspaceController.removeListener(_onCodeTextChanged);
    _codeWorkspaceController.dispose(); 
    if (!kIsWeb) {
      _engine.leaveChannel();
      _engine.release();
    }
    super.dispose();
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
          appId: "YOUR_AGORA_APP_ID", // Replace with your Agora App ID
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
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
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
        token: "YOUR_TOKEN", // Replace with your token or temp token
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

  void _onToggleCamera() {
    setState(() {
      _camEnabled = !_camEnabled;
    });
    if (!kIsWeb) {
      _engine.enableLocalVideo(_camEnabled);
    }
  }

  // --- TOGGLE SHARED BREAK STATE ---
  Future<void> _toggleBreak() async {
    final newPauseState = !_isPaused;
    setState(() {
      _isPaused = newPauseState;
    });

    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
      'isPaused': newPauseState,
    });
  }

  void _startSessionStopwatch() {
    _sessionClockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _listenForLiveSessionUpdates() {
    _sessionDocumentSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      
      final data = snapshot.data()!;
      
      if (data['status'] == 'completed') {
        _sessionClockTimer?.cancel();
        _showTerminationSummaryDialog(data);
        return;
      }

      final bool remotePauseState = data['isPaused'] ?? false;
      if (remotePauseState != _isPaused) {
        setState(() {
          _isPaused = remotePauseState;
        });
      }

      final String remoteCode = data['sharedCodeCanvasText'] ?? '';
      if (remoteCode != _codeWorkspaceController.text) {
        _isLocalUpdate = true; 
        
        final previousSelection = _codeWorkspaceController.selection;
        _codeWorkspaceController.text = remoteCode;
        
        try {
          _codeWorkspaceController.selection = previousSelection;
        } catch (_) {
          _codeWorkspaceController.selection = TextSelection.collapsed(offset: remoteCode.length);
        }
        
        _isLocalUpdate = false; 
      }
    });
  }

  void _onCodeTextChanged() {
    if (_isLocalUpdate) return; 

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .update({
        'sharedCodeCanvasText': _codeWorkspaceController.text,
        'lastEditedBy': widget.role,
      });
    });
  }

  String _formatDigitalClock(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Future<void> _endLiveSessionChannel() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    _sessionClockTimer?.cancel();
    _debounceTimer?.cancel();

    if (!kIsWeb) {
      _engine.leaveChannel();
    }

    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId);
    
    try {
      final snapshot = await sessionRef.get();
      final data = snapshot.data() ?? {};
      
      // Standard platform rate of $0.10 per minute
      const double ratePerMin = 0.10;

      int totalMinutes = (_secondsElapsed / 60).ceil();
      if (totalMinutes < 1 && _secondsElapsed > 0) {
        totalMinutes = 1;
      }

      final double totalCostUSD = totalMinutes * ratePerMin;

      // Atomic batch write for session completion & mentor earnings credit
      final batch = FirebaseFirestore.instance.batch();

      batch.update(sessionRef, {
        'status': 'completed',
        'totalMinutesTaught': totalMinutes,
        'finalCostUSD': totalCostUSD,
        'endedAt': FieldValue.serverTimestamp(),
      });

      if (widget.role == 'mentor') {
        final mentorUid = data['mentorId'];
        if (mentorUid != null) {
          final mentorRef = FirebaseFirestore.instance.collection('users').doc(mentorUid);
          batch.update(mentorRef, {
            'mentorEarningsUSD': FieldValue.increment(totalCostUSD),
            'isOnline': false, 
          });
          
          // Clean up availability node if present
          batch.delete(FirebaseFirestore.instance.collection('available_mentors').doc(mentorUid));
        }
      }

      await batch.commit();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error ending session: $e")));
      }
    } finally {
      if (mounted) setState(() => _isEnding = false);
    }
  }

  void _showTerminationSummaryDialog(Map<String, dynamic> sessionData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text("Session Closed", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Duration: ${_formatDigitalClock(sessionData['durationSeconds'] ?? _secondsElapsed)}"),
            const SizedBox(height: 8),
            Text("Total Earnings Credited: \$${(sessionData['finalCostUSD'] ?? 0.00).toStringAsFixed(2)}"),
            const SizedBox(height: 12),
            const Text(
              "Session balance metrics synchronized successfully across account profiles.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context); 
            },
            child: const Text("Return to Dashboard", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00796B))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color sessionColor = widget.role == 'mentor' 
        ? const Color(0xFF00796B) 
        : const Color(0xFF333697);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.role == 'mentor' ? 'Expert Workspace Panel' : 'Mentee Classroom Container'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false,
        actions: [
          if (_isPaused)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "PAUSED",
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _isPaused ? Colors.orange.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: _isPaused ? Colors.orange : Colors.red, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    _formatDigitalClock(_secondsElapsed),
                    style: TextStyle(
                      color: _isPaused ? Colors.orange.shade800 : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 180,
            margin: const EdgeInsets.all(16),
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
                            connection: RtcConnection(channelId: widget.sessionId),
                          ),
                        )
                      : const Text(
                          'Waiting for other participant...',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
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
                                child: const Icon(Icons.videocam_off, color: Colors.white, size: 20),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E), 
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.terminal, color: sessionColor, size: 16), 
                          const SizedBox(width: 8),
                          const Text(
                            "Shared Engineering Code Canvas (.dart / .plc)",
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          controller: _codeWorkspaceController,
                          maxLines: null, 
                          keyboardType: TextInputType.multiline,
                          style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 14, height: 1.4),
                          decoration: const InputDecoration(
                            hintText: "// Paste compile errors, Flutter widgets, or system logic rungs here for instant collaboration view...",
                            hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'mentor_mute',
                  onPressed: _onToggleMute,
                  backgroundColor: _muted ? Colors.red : Colors.grey.shade200,
                  child: Icon(_muted ? Icons.mic_off : Icons.mic, color: _muted ? Colors.white : Colors.black87),
                ),
                FloatingActionButton(
                  heroTag: 'mentor_cam',
                  onPressed: _onToggleCamera,
                  backgroundColor: !_camEnabled ? Colors.red : Colors.grey.shade200,
                  child: Icon(_camEnabled ? Icons.videocam : Icons.videocam_off, color: !_camEnabled ? Colors.white : Colors.black87),
                ),
                FloatingActionButton(
                  heroTag: 'mentor_break',
                  onPressed: _toggleBreak,
                  backgroundColor: _isPaused ? Colors.green.shade100 : Colors.orange.shade100,
                  child: Icon(
                    _isPaused ? Icons.play_arrow : Icons.pause,
                    color: _isPaused ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: _isEnding
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)))
                        : ElevatedButton.icon(
                            onPressed: _endLiveSessionChannel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            icon: const Icon(Icons.call_end, color: Colors.white),
                            label: const Text("End Session", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
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