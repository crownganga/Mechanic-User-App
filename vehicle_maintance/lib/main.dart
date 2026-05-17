import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/notification_service.dart';

import 'package:vehicle_maintance/screens/auth/onboarding/onboarding_slide1.dart';
import 'package:vehicle_maintance/screens/auth/session_manager.dart';
import 'package:vehicle_maintance/screens/splash_screen.dart';
import 'package:vehicle_maintance/MainScreens/Dashboard/dashboard_screen.dart';

// 🔔 ADD THIS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ SUPABASE INIT
  await Supabase.initialize(
    url: 'https://ovqrpxeyayjfplpjauyr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im92cXJweGV5YXlqZnBscGphdXlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU0NDk1NjgsImV4cCI6MjA4MTAyNTU2OH0.uAa1J1cR-g2dDO6dUmZ_7BaIL8yQMvkSFhdYgjuwM4A',
  );

  // 🔔 NOTIFICATION INIT (VERY IMPORTANT)
  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Decide first screen AFTER splash
  Future<Widget> getStartScreen() async {
    final user = Supabase.instance.client.auth.currentUser;
    final isValid = await SessionManager.isSessionValid();

    if (user != null && isValid) {
      return const DashboardScreen(); // 🚀 Auto-login
    } else {
      await SessionManager.logout(); // ⛔ Session expired
      return const OnboardSlideOne();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      home: SplashScreen(
        nextScreenBuilder: () async {
          return await getStartScreen();
        },
      ),
    );
  }
}
