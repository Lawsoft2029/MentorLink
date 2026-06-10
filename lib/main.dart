import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:mentorlinks_app_project/features/auth/logic/auth_gate.dart';

// --- NEW IMPORTS FOR NAVIGATION ---
import 'package:mentorlinks_app_project/features/auth/presentation/interests_screen.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/tier_selection_screen.dart';
import 'package:mentorlinks_app_project/features/mentee/presentation/mentee_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GoogleFonts.config.allowRuntimeFetching = false;
  
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCeQEU7H2p4cfo329zyytBFVmPB9uWB7Ac",
        authDomain: "mentorlinks-c6729.firebaseapp.com",
        projectId: "mentorlinks-c6729",
        storageBucket: "mentorlinks-c6729.firebasestorage.app",
        messagingSenderId: "858429737751",
        appId: "1:858429737751:web:d92309b6d38912c4ad4552",
        measurementId: "G-LVGXXLWFBF",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(
    const ProviderScope(
      child: MentorLinksApp(),
    ),
  );
}

class MentorLinksApp extends StatelessWidget {
  const MentorLinksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MentorLinks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF333697),
          primary: const Color(0xFF333697),
        ),
      ),
      // AuthGate handles the initial session check
      home: const AuthGate(), 
      
      // --- ROUTES DEFINED CORRECTLY ---
      routes: {
        '/interests': (context) => const CourseSelectionScreen(), 
        '/tier-selection': (context) => const TierSelectionScreen(),
        '/mentee-dashboard': (context) => const MenteeDashboard(),
      },
    );
  }
}