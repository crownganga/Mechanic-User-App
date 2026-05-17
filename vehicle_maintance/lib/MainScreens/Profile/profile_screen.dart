import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vehicle_maintance/MainScreens/Profile/edit_profile_screen.dart';
import 'package:vehicle_maintance/MainScreens/Profile/booking_history_screen.dart';
import 'package:vehicle_maintance/MainScreens/Profile/vehicle_detail.dart';
import 'package:vehicle_maintance/MainScreens/bottom_menu.dart';
import 'package:vehicle_maintance/screens/auth/onboarding/onboarding_slide1.dart';
import 'package:vehicle_maintance/screens/splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> serviceHistory = [];
  bool historyLoading = true;

  Map<String, dynamic>? userData;
  Map<String, dynamic>? vehicleData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchProfile();
    fetchServiceHistory(); // 🔥 ADD THIS
  }

  Future<void> fetchServiceHistory() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('service_requests')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    /*    setState(() {
      serviceHistory = List<Map<String, dynamic>>.from(response);
      historyLoading = false;
    });*/
  }

  Future<void> fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final userRes = await supabase
        .from('users_data')
        .select()
        .eq('id', user.id)
        .single();

    final vehicleRes = await supabase
        .from('vehicles')
        .select()
        .eq('user_id', user.id)
        .eq('is_primary', true) // ⭐ HERE IS THE FIX
        .maybeSingle();

    setState(() {
      userData = userRes;
      vehicleData = vehicleRes;
      loading = false;
    });
  }

  String safe(dynamic v) =>
      v == null || v.toString().isEmpty ? "N/A" : v.toString();

  String profileValue(dynamic value, String placeholder) {
    if (value == null || value.toString().trim().isEmpty) {
      return placeholder;
    }
    return value.toString();
  }

  IconData getVehicleIcon() {
    final type = vehicleData?['vehicle_type']?.toString().toLowerCase();

    if (type == 'bike' || type == 'two_wheeler') {
      return Icons.two_wheeler;
    }
    return Icons.directions_car; // default
  }

  Future<void> openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication, // 🔥 opens browser directly
    )) {
      throw 'Could not open document';
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? "";

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
                MaterialPageRoute(builder: (_) => const EditprofileScreen()),
              );
              fetchProfile();
            },
            child: const Text(
              "Edit",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            /// 👤 PROFILE IMAGE
            CircleAvatar(
              radius: 50,
              backgroundImage: userData?['profile_image_url'] != null
                  ? NetworkImage(userData!['profile_image_url'])
                  : const AssetImage("assets/user.png") as ImageProvider,
            ),

            const SizedBox(height: 12),

            /// NAME
            Text(
              profileValue(userData?['name'], "Name"),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            /// EMAIL
            Text(
              email,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),

            const SizedBox(height: 6),

            /// PHONE
            Text(
              profileValue(userData?['phone'], "Phone"),
              style: const TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 6),

            /// LOCATION
            Text(
              profileValue(userData?['location'], "Location"),
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            /// 🚗 VEHICLE DETAILS HEADER
            Row(
              children: [
                const Text(
                  "Vehicle Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                /*         IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditvehicleScreen(),
                      ),
                    );
                    fetchProfile();
                  },
                ),*/
              ],
            ),

            const SizedBox(height: 12),

            /// VEHICLE ROW (FLAT STYLE)
            if (vehicleData != null)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          VehicleDetailScreen(vehicle: vehicleData!),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        getVehicleIcon(),
                        size: 32,
                        color: const Color(0xFF0F4DAB),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${safe(vehicleData!['brand'])} ${safe(vehicleData!['model'])}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            safe(vehicleData!['registration_number']),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              const Text("No vehicle registered"),

            //RC book viewer button
            const SizedBox(height: 20),

            /// 📘 PRIMARY VEHICLE RC BOOK (DIRECT BROWSER OPEN)
            if (vehicleData != null &&
                vehicleData!['is_primary'] == true &&
                vehicleData!['rc_book_url'] != null &&
                vehicleData!['rc_book_url'].toString().isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  openInBrowser(vehicleData!['rc_book_url']);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description,
                        size: 30,
                        color: Color(0xFF0F4DAB),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Primary Vehicle RC Book",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Tap to open in browser",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              const Text(
                "Primary vehicle RC book not uploaded",
                style: TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 20),

            /// 🛡️ PRIMARY VEHICLE INSURANCE (DIRECT OPEN)
            if (vehicleData != null &&
                vehicleData!['is_primary'] == true &&
                vehicleData!['insurance_copy_url'] != null &&
                vehicleData!['insurance_copy_url'].toString().isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  openInBrowser(vehicleData!['insurance_copy_url']);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 30,
                        color: Color(0xFF0F4DAB),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Primary Vehicle Insurance",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Tap to open in browser",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              const Text(
                "Primary vehicle insurance copy not uploaded",
                style: TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 30),

            /// 📜 SERVICE HISTORY HEADER
            Row(
              children: const [
                Text(
                  "Service History",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 15),

            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookingHistoryScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.history, color: Color(0xFF0F4DAB)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Booking History",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            /// 🚪 LOGOUT BUTTON
            TextButton.icon(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();

                if (!mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => SplashScreen(
                      nextScreenBuilder: () async {
                        return const OnboardSlideOne();
                      },
                    ),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.power_settings_new, color: Colors.red),
              label: const Text(
                "Log Out",
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
          ],
        ),
      ),

      /// 🔻 BOTTOM MENU
      bottomNavigationBar: const BottomMenu(selectedIndex: 4),
    );
  }
}
