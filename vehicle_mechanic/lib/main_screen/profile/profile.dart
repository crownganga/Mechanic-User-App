import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_mechanic/auth/mechanic_login_screen.dart';
import 'package:vehicle_mechanic/main_screen/bottom_menu.dart';
import 'package:vehicle_mechanic/main_screen/profile/editmachanic_profile.dart';
import 'package:vehicle_mechanic/main_screen/profile/location_service.dart';

class MechanicProfileScreen extends StatefulWidget {
  const MechanicProfileScreen({super.key});

  @override
  State<MechanicProfileScreen> createState() => _MechanicProfileScreenState();
}

class _MechanicProfileScreenState extends State<MechanicProfileScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? mechanic;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchMechanicProfile(); // ✅ FAST
    updateLocationInBackground(); // 🔄 NON-BLOCKING
  }

  // ================= FETCH PROFILE (FAST) =================
  Future<void> fetchMechanicProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('mechanics')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (!mounted) return;

    setState(() {
      mechanic = res;
      loading = false; // ✅ UI RELEASED IMMEDIATELY
    });
  }

  // ================= UPDATE LOCATION (BACKGROUND) =================
  Future<void> updateLocationInBackground() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final locationData = await LocationService.getCurrentLocation().timeout(
        const Duration(seconds: 10),
      );

      // Map usage
      await supabase.from('mechanic_locations').upsert({
        'mechanic_id': user.id,
        'latitude': locationData['latitude'],
        'longitude': locationData['longitude'],
      });

      // Profile display
      await supabase
          .from('mechanics')
          .update({'location': locationData['address']})
          .eq('id', user.id);

      if (mounted) {
        setState(() {
          mechanic?['location'] = locationData['address'];
        });
      }
    } catch (e) {
      debugPrint("Location update skipped: $e");
    }
  }

  // ================= SAFE TEXT =================
  String safe(dynamic value, String placeholder) {
    if (value == null) return placeholder;
    final text = value.toString().trim();
    return text.isEmpty ? placeholder : text;
  }

  // ================= PROFILE IMAGE =================
  Widget profileImage() {
    final imageUrl = mechanic?['profile_image_url'];

    if (imageUrl == null || imageUrl.isEmpty) {
      return const CircleAvatar(
        radius: 50,
        backgroundImage: AssetImage("assets/user.png"),
      );
    }

    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Image.asset("assets/user.png", fit: BoxFit.cover),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? "";

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        title: const Text("Profile"),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditMechanicProfileScreen(),
                ),
              );
              fetchMechanicProfile();
            },
            child: const Text("Edit", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            profileImage(),
            const SizedBox(height: 12),

            Text(
              safe(mechanic?['name'], "Mechanic Name"),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              safe(mechanic?['workshop_name'], "Workshop Name"),
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            detailsCard([
              profileRow(Icons.email, email),
              profileRow(Icons.phone, safe(mechanic?['phone'], "Phone")),
              profileRow(
                Icons.location_on,
                safe(mechanic?['location'], "Detecting location..."),
              ),
              profileRow(
                Icons.build,
                "Experience: ${safe(mechanic?['experience_years'], "0")} Years",
              ),
              profileRow(
                Icons.my_location,
                "Available: ${safe(mechanic?['availability_km'], "0")} KM",
              ),
            ]),

            const SizedBox(height: 40),
            logoutButton(context),
          ],
        ),
      ),

      bottomNavigationBar: const BottomMenu(selectedIndex: 3),
    );
  }

  // ================= UI HELPERS =================
  Widget detailsCard(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: children),
  );

  Widget profileRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    ),
  );

  Widget logoutButton(BuildContext context) => TextButton.icon(
    onPressed: () async {
      await supabase.auth.signOut();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MechanicLoginScreen()),
        (_) => false,
      );
    },
    icon: const Icon(Icons.power_settings_new, color: Colors.red),
    label: const Text(
      "Log Out",
      style: TextStyle(color: Colors.red, fontSize: 18),
    ),
  );
}
