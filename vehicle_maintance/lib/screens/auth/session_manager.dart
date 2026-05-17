import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionManager {
  static const String loginTimeKey = "login_time";
  static const int sessionHours = 3;

  // Save login time
  static Future<void> saveLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(loginTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Check session validity
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getInt(loginTimeKey);

    if (savedTime == null) return false;

    final loginTime = DateTime.fromMillisecondsSinceEpoch(savedTime);
    final diff = DateTime.now().difference(loginTime);

    return diff.inHours < sessionHours;
  }

  // Logout user
  static Future<void> logout() async {
    final supabase = Supabase.instance.client;
    await supabase.auth.signOut();
  }
}
