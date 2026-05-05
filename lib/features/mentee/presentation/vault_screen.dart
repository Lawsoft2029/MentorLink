import 'package:flutter/material.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text("My Learning Vault", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Storage Status Card
          _buildStorageInfo(),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text("Saved Lectures", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          // List of Videos
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 3, // Placeholder
              itemBuilder: (context, index) {
                return _buildVideoCard();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF333697),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Offline Storage", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          const Text("1.2 GB / 5.0 GB used", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: 0.24,
            backgroundColor: Colors.white24,
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: Container(
          width: 80,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
            image: const DecorationImage(
              image: NetworkImage('https://via.placeholder.com/100'),
              fit: BoxFit.cover,
            ),
          ),
          child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
        ),
        title: const Text("IoT Architecture Basics", style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text("Instructor: Engr. Samuel\nDuration: 45 mins", style: TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.more_vert),
        isThreeLine: true,
      ),
    );
  }
}