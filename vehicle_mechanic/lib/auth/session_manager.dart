import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_mechanic/auth/mechanic_login_screen.dart';
import 'package:vehicle_mechanic/main_screen/dashboard/mechanic_dashboard_screen.dart';

class SessionManager extends StatelessWidget {
  const SessionManager({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    // ✅ Already logged in
    if (session != null) {
      return const MechanicDashboardScreen();
    }

    // ❌ Not logged in
    return const MechanicLoginScreen();
  }
}
