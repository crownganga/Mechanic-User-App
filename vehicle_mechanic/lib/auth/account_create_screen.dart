import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mechanic_login_screen.dart';

class CreateMechanicAccountScreen extends StatefulWidget {
  const CreateMechanicAccountScreen({super.key});

  @override
  State<CreateMechanicAccountScreen> createState() =>
      _CreateMechanicAccountScreenState();
}

class _CreateMechanicAccountScreenState
    extends State<CreateMechanicAccountScreen> {
  final supabase = Supabase.instance.client;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _showPass = false;
  bool _showConfirm = false;

  // ================= CREATE MECHANIC =================
  Future<void> createMechanicAccount() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      _showSnack("Please fill all fields", Colors.red);
      return;
    }

    if (password != confirm) {
      _showSnack("Passwords do not match", Colors.red);
      return;
    }

    setState(() => _loading = true);

    try {
      // 🔐 STEP 1: SIGN UP
      final signUpRes = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (signUpRes.user == null) {
        throw 'Signup failed';
      }

      // 🔑 STEP 2: SIGN IN (VERY IMPORTANT)
      final signInRes = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = signInRes.user;
      if (user == null) {
        throw 'Login failed after signup';
      }

      // 🧑‍🔧 STEP 3: INSERT INTO mechanics (NOW RLS PASSES)
      await supabase.from('mechanics').insert({
        'user_id': user.id,
        'name': name,
        'email': email,
        'phone': phone,
        'is_active': true,
      });

      _showSnack("Mechanic registered successfully", Colors.green);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MechanicLoginScreen()),
      );
    } catch (e) {
      debugPrint("❌ MECHANIC CREATE ERROR => $e");
      _showSnack("Error: $e", Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.build,
                    size: 42,
                    color: Color(0xFF0F4DAB),
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  "Mechanic Registration",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4DAB),
                  ),
                ),

                const SizedBox(height: 26),

                _inputField(_nameCtrl, "Mechanic Name", Icons.person),
                _inputField(_emailCtrl, "Email", Icons.email),
                _inputField(
                  _phoneCtrl,
                  "Phone",
                  Icons.call,
                  keyboard: TextInputType.phone,
                ),

                _passwordInput(
                  _passwordCtrl,
                  "Password",
                  _showPass,
                  () => setState(() => _showPass = !_showPass),
                ),

                _passwordInput(
                  _confirmCtrl,
                  "Confirm Password",
                  _showConfirm,
                  () => setState(() => _showConfirm = !_showConfirm),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : createMechanicAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4DAB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Create Account",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _passwordInput(
    TextEditingController controller,
    String label,
    bool visible,
    VoidCallback toggle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: !visible,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
            onPressed: toggle,
          ),
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
