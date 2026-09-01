import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // IMPORT DOTENV
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mentorlinks_app_project/features/auth/services/notification_service.dart';
import 'package:mentorlinks_app_project/features/kyc/presentation/kyc_screen.dart'; 
import 'features/auth/presentation/splash_screen.dart'; 
import 'package:mentorlinks_app_project/features/auth/presentation/interests_screen.dart';
import 'package:mentorlinks_app_project/features/auth/presentation/tier_selection_screen.dart';
import 'package:mentorlinks_app_project/features/mentee/presentation/mentee_dashboard.dart';
import 'package:mentorlinks_app_project/features/home/presentation/main_dashboard_screen.dart'; // ADDED MAIN DASHBOARD IMPORT
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Add import

// --- BACKGROUND MESSAGING HANDLER ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling background notification: ${message.messageId}");
}
  

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase safely once based on platform
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

  // Register background handler statically via FirebaseMessaging class
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await NotificationService.initialize(); // Corrected static call
  } catch (e) {
    debugPrint('NotificationService initialization error: $e');
  }

  // Initialize Mobile Ads SDK on mobile platforms
  if (!kIsWeb) {
    MobileAds.instance.initialize();
  }
  
  // LOAD SECURE ENVIRONMENT VARIABLES FROM .env
  await dotenv.load(fileName: ".env");

  // ONLY ENABLE OFFLINE CACHING ON MOBILE (Web does not support SQLite persistence this way)
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
  
  GoogleFonts.config.allowRuntimeFetching = true;

  runApp(
    const ProviderScope(
      child: MentorLinksApp(),
    ),
  );
}

class AuthCheckWrapper extends StatelessWidget {
  const AuthCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF333697))),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const MainDashboardScreen();
        }

        // Fallback or splash reference if user is unauthenticated
        return const SplashScreen();
      },
    );
  }
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
      // AuthCheckWrapper handles authentication session checks seamlessly
      home: const AuthCheckWrapper(), 
      
      // --- ROUTES DEFINED CORRECTLY ---
      routes: {
        '/interests': (context) => const CourseSelectionScreen(), 
        '/tier-selection': (context) => const TierSelectionScreen(),
        '/mentee-dashboard': (context) => const MenteeDashboard(),
        '/main-dashboard': (context) => const MainDashboardScreen(),
        '/kyb': (context) => const KybScreen(), // ADDED KYB ROUTE
      },
    );
  }
}