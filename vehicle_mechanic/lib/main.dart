import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_mechanic/auth/mechanic_login_screen.dart';
import 'package:vehicle_mechanic/main_screen/booking/notification_service.dart';
import 'package:vehicle_mechanic/main_screen/dashboard/mechanic_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ovqrpxeyayjfplpjauyr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im92cXJweGV5YXlqZnBscGphdXlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU0NDk1NjgsImV4cCI6MjA4MTAyNTU2OH0.uAa1J1cR-g2dDO6dUmZ_7BaIL8yQMvkSFhdYgjuwM4A',
  );
  await NotificationService.init();

  runApp(const MechanicApp());
}

class MechanicApp extends StatefulWidget {
  const MechanicApp({super.key});

  @override
  State<MechanicApp> createState() => _MechanicAppState();
}

class _MechanicAppState extends State<MechanicApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vehicle Maintenance - Mechanic',
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final session = Supabase.instance.client.auth.currentSession;

          if (session != null) {
            return const MechanicDashboardScreen();
          }

          return const MechanicLoginScreen();
        },
      ),
    );
  }
}
