import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// Request permission for push notifications from the user (iOS & Android 13+)
  Future<void> requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission.');
    } else {
      debugPrint('User declined or did not grant permission.');
    }
  }

  /// Get the device FCM Token (used to send targeted push notifications)
  Future<String?> getDeviceToken() async {
    String? token = await _firebaseMessaging.getToken();
    debugPrint("FCM Device Token: $token");
    return token;
  }

  /// Listen to foreground messages
  void listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received a foreground message: ${message.notification?.title}');
    });
  }
}