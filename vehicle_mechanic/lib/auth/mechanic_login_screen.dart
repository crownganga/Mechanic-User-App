import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_create_screen.dart';
import '../main_screen/dashboard/mechanic_dashboard_screen.dart';

class MechanicLoginScreen extends StatefulWidget {
  const MechanicLoginScreen({super.key});

  @override
  State<MechanicLoginScreen> createState() => _MechanicLoginScreenState();
}

class _MechanicLoginScreenState extends State<MechanicLoginScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  // 🔐 HASH PASSWORD
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // ================= LOGIN FUNCTION =================
  Future<void> loginMechanic() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Please fill all fields", Colors.red);
      return;
    }

    setState(() => _loading = true);

    try {
      // 1️⃣ AUTH LOGIN (Supabase)
      final authRes = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = authRes.user;
      if (user == null) {
        throw "Invalid email or password";
      }

      // 2️⃣ GET MECHANIC DATA
      final mechanic = await supabase
          .from('mechanics')
          .select('password_hash, is_active')
          .eq('id', user.id)
          .single();

      // 3️⃣ VERIFY PASSWORD HASH
      final inputHash = _hashPassword(password);
      if (mechanic['password_hash'] != inputHash) {
        await supabase.auth.signOut();
        throw "Incorrect password";
      }

      // 4️⃣ CHECK ACTIVE STATUS
      if (mechanic['is_active'] != true) {
        await supabase.auth.signOut();
        throw "Mechanic account is disabled";
      }

      // 5️⃣ SUCCESS
      _showSnack("Login successful", Colors.green);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
      );
    } catch (e) {
      _showSnack(e.toString(), Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 20),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.build, size: 70, color: Color(0xFF0F4DAB)),
                const SizedBox(height: 12),

                const Text(
                  "Mechanic Login",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4DAB),
                  ),
                ),

                const SizedBox(height: 28),

                _inputField(
                  controller: _emailCtrl,
                  label: "Email",
                  icon: Icons.email,
                ),

                _passwordField(),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : loginMechanic,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4DAB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateMechanicAccountScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Create Mechanic Account",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF0F4DAB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= INPUTS =================
  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _passwordCtrl,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: "Password",
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => _obscure = !_obscure);
            },
          ),
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ================= SNACK =================
  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
