import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  Timer? _debounceTimer; // NEW: Controls the keystroke broadcast throttle buffer
  StreamSubscription<DocumentSnapshot>? _sessionDocumentSubscription; // NEW: Listens for text edits from the other user
  
  int _secondsElapsed = 0;
  bool _isEnding = false; 
  bool _isLocalUpdate = false; // NEW: Flags local changes to prevent infinite cursor feedback loops

  @override
  void initState() {
    super.initState();
    _startSessionStopwatch();
    _listenForLiveSessionUpdates();
    _codeWorkspaceController.addListener(_onCodeTextChanged); // NEW: Watch for keypad input changes
  }

  @override
  void dispose() {
    _sessionClockTimer?.cancel();
    _debounceTimer?.cancel();
    _sessionDocumentSubscription?.cancel();
    _codeWorkspaceController.removeListener(_onCodeTextChanged);
    _codeWorkspaceController.dispose(); 
    super.dispose();
  }

  void _startSessionStopwatch() {
    _sessionClockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  // REAL-TIME SYNC LISTENER: Detects when the code text changes in the database
  void _listenForLiveSessionUpdates() {
    _sessionDocumentSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      
      final data = snapshot.data()!;
      
      // Handle automatic session teardown if a user triggers completion
      if (data['status'] == 'completed') {
        _sessionClockTimer?.cancel();
        _showTerminationSummaryDialog(data);
        return;
      }

      // Sync the incoming code text only if it didn't originate from this device
      final String remoteCode = data['sharedCodeCanvasText'] ?? '';
      if (remoteCode != _codeWorkspaceController.text) {
        _isLocalUpdate = true; // Raise lock flag safely
        
        // Save current cursor location configuration before replacing content
        final previousSelection = _codeWorkspaceController.selection;
        _codeWorkspaceController.text = remoteCode;
        
        // Restore cursor selection parameters to avoid snapping text pointer to the front
        try {
          _codeWorkspaceController.selection = previousSelection;
        } catch (_) {
          _codeWorkspaceController.selection = TextSelection.collapsed(offset: remoteCode.length);
        }
        
        _isLocalUpdate = false; // Drop lock flag
      }
    });
  }

  // KEYSTROKE THROTTLE ENGINE: Debounces writes to avoid slamming Firestore on every single letter typed
  void _onCodeTextChanged() {
    if (_isLocalUpdate) return; // Ignore updates that come from the database listener

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

    final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId);
    
    try {
      final snapshot = await sessionRef.get();
      final data = snapshot.data() ?? {};
      final double ratePerMin = (data['connectionRatePerMin'] ?? 0.20).toDouble();

      final int totalMinutes = (_secondsElapsed / 60).ceil();
      final double totalCostUSD = totalMinutes * ratePerMin;

      await sessionRef.update({
        'status': 'completed',
        'durationSeconds': _secondsElapsed,
        'finalCostUSD': totalCostUSD,
        'endedAt': FieldValue.serverTimestamp(),
      });

      if (widget.role == 'mentor') {
        final mentorUid = data['mentorId'];
        if (mentorUid != null) {
          await FirebaseFirestore.instance.collection('users').doc(mentorUid).update({
            'mentorEarningsUSD': FieldValue.increment(totalCostUSD),
            'isOnline': false, 
          });
          await FirebaseFirestore.instance.collection('available_mentors').doc(mentorUid).delete();
        }
      }

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
            Text("Total Cost: \$${(sessionData['finalCostUSD'] ?? 0.00).toStringAsFixed(2)}"),
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
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    _formatDigitalClock(_secondsElapsed),
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: _isEnding
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)))
                : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _endLiveSessionChannel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: const Icon(Icons.call_end, color: Colors.white),
                      label: const Text("End Telemetry Handshake", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}