import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/roadmap_service.dart';

class SkillRoadmapScreen extends StatefulWidget {
  const SkillRoadmapScreen({super.key});

  @override
  State<SkillRoadmapScreen> createState() => _SkillRoadmapScreenState();
}

class _SkillRoadmapScreenState extends State<SkillRoadmapScreen> {
  final RoadmapService _roadmapService = RoadmapService();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Learning Roadmap"),
        backgroundColor: const Color(0xFF333697),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _roadmapService.getMenteeRoadmap(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Initializing roadmap..."));
          }

          final data = snapshot.data!.data()!;
          final trackName = data['trackName'] ?? 'Engineering Track';
          final List milestones = data['milestones'] ?? [];

          // Calculate progress percentage
          int completedCount = milestones
              .where((m) => m['completed'] == true)
              .length;
          double progress = milestones.isEmpty
              ? 0
              : completedCount / milestones.length;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Track Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333697).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF333697).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Active Learning Track",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trackName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333697),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade300,
                        color: const Color(0xFF00796B),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${(progress * 100).toInt()}% Completed ($completedCount of ${milestones.length} milestones)",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00796B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Curriculum Checkpoints",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333697),
                  ),
                ),
                const SizedBox(height: 12),

                // Milestones List
                Expanded(
                  child: ListView.builder(
                    itemCount: milestones.length,
                    itemBuilder: (context, index) {
                      final milestone = milestones[index];
                      final isCompleted = milestone['completed'] ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            milestone['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCompleted ? Colors.grey : Colors.black87,
                            ),
                          ),
                          value: isCompleted,
                          activeColor: const Color(0xFF00796B),
                          onChanged: (bool? value) {
                            _roadmapService.toggleMilestone(milestones, index);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
