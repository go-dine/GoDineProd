import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
