import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If your app is in the background or terminated, this will be called.
  // The system tray notification is automatically handled by Firebase for 'notification' payloads.
  // No need to manually show locally unless it's a 'data-only' message.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase not initialized: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.bg,
    statusBarIconBrightness: Brightness.light,
  ));
  
  // Launch the UI immediately. 
  // Initializations (Supabase, Notifications) are handled inside AuthGate,
  // which is reached immediately after the 2-second SplashScreen animation.
  runApp(const GoDineApp());
}

class GoDineApp extends StatelessWidget {
  const GoDineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go Dine Owner',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // The app now starts with a beautiful 2-second boot animation
      home: const SplashScreen(),
    );
  }
}
