import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_mechanic/main_screen/profile/location_service.dart';

class EditMechanicProfileScreen extends StatefulWidget {
  const EditMechanicProfileScreen({super.key});

  @override
  State<EditMechanicProfileScreen> createState() =>
      _EditMechanicProfileScreenState();
}

class _EditMechanicProfileScreenState extends State<EditMechanicProfileScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker picker = ImagePicker();
  final locationDisplayCtrl = TextEditingController();

  String? autoLocation;

  bool saving = false;

  // Controllers
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final workshopCtrl = TextEditingController();
  //  final locationCtrl = TextEditingController();
  final expCtrl = TextEditingController();
  final kmCtrl = TextEditingController();

  String? profileImageUrl;
  File? pickedImage;

  @override
  void initState() {
    super.initState();
    initScreen();
  }

  Future<void> initScreen() async {
    await loadMechanicData(); // only load saved location
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    workshopCtrl.dispose();
    expCtrl.dispose();
    kmCtrl.dispose();
    locationDisplayCtrl.dispose(); // ✅ ADD
    super.dispose();
  }

  Future<void> fetchLocationOnIconClick() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() {
        locationDisplayCtrl.text = "Fetching current location...";
      });

      final locationData = await LocationService.getCurrentLocation().timeout(
        const Duration(seconds: 20),
      );

      await supabase
          .from('mechanics')
          .update({
            'latitude': locationData['latitude'],
            'longitude': locationData['longitude'],
            'location': locationData['address'],
          })
          .eq('id', user.id);

      if (!mounted) return;

      setState(() {
        autoLocation = locationData['address'];
        locationDisplayCtrl.text = locationData['address'];
      });
    } catch (e) {
      debugPrint("❌ Location error: $e");

      if (!mounted) return;

      setState(() {
        locationDisplayCtrl.text = autoLocation ?? "Location not available";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Location error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= LOAD MECHANIC DATA =================
  Future<void> loadMechanicData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('mechanics')
        .select()
        .eq('id', user.id)
        .single();

    nameCtrl.text = res['name'] ?? '';
    emailCtrl.text = res['email'] ?? '';
    phoneCtrl.text = res['phone'] ?? '';
    workshopCtrl.text = res['workshop_name'] ?? '';
    expCtrl.text = res['experience_years']?.toString() ?? '';
    kmCtrl.text = res['availability_km']?.toString() ?? '';
    profileImageUrl = res['profile_image_url'];

    autoLocation = res['location'];

    if (locationDisplayCtrl.text.isEmpty) {
      locationDisplayCtrl.text = autoLocation ?? "Detecting location...";
    }

    if (mounted) setState(() {});
  }

  Future<void> updateLocationAutomatically() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final locationData = await LocationService.getCurrentLocation();

      await supabase
          .from('mechanics')
          .update({
            'latitude': locationData['latitude'],
            'longitude': locationData['longitude'],
            'location': locationData['address'],
          })
          .eq('id', user.id);

      if (mounted) {
        setState(() {
          autoLocation = locationData['address'];
          locationDisplayCtrl.text = locationData['address']; // ✅ THIS FIXES IT
        });
      }
    } catch (e) {
      debugPrint("Location update failed: $e");
    }
  }

  // ================= IMAGE PICK =================
  Future<void> pickProfileImage(BuildContext context) async {
    final user = supabase.auth.currentUser!;
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    final file = File(image.path);
    final fileName = "${user.id}${p.extension(image.path)}";

    await supabase.storage
        .from('profile_images')
        .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

    final imageUrl = supabase.storage
        .from('profile_images')
        .getPublicUrl(fileName);

    if (!mounted) return;

    setState(() {
      pickedImage = file;
      profileImageUrl = imageUrl;
    });
  }

  // ================= SAVE =================
  Future<void> saveProfile(BuildContext ctx) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => saving = true);

    try {
      final user = supabase.auth.currentUser!;

      await supabase
          .from('mechanics')
          .update({
            'name': nameCtrl.text.trim(),
            'phone': phoneCtrl.text.trim(),
            'workshop_name': workshopCtrl.text.trim(),
            'experience_years': int.tryParse(expCtrl.text),
            'availability_km': int.tryParse(kmCtrl.text),
            'profile_image_url': profileImageUrl,
          })
          .eq('id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text("Profile updated successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(ctx);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text("Update failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // ================= IMAGE WIDGET (FIXED) =================
  Widget editProfileImage() {
    if (pickedImage != null) {
      return CircleAvatar(radius: 55, backgroundImage: FileImage(pickedImage!));
    }

    if (profileImageUrl == null || profileImageUrl!.isEmpty) {
      return const CircleAvatar(
        radius: 55,
        backgroundImage: AssetImage("assets/user.png"),
      );
    }

    return CircleAvatar(
      radius: 55,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: Image.network(
          profileImageUrl!,
          width: 110,
          height: 110,
          fit: BoxFit.cover,
          key: ValueKey(profileImageUrl), // 🔥 instant refresh
          errorBuilder: (_, __, ___) => Image.asset("assets/user.png"),
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // PROFILE IMAGE
            Center(
              child: Stack(
                children: [
                  editProfileImage(),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => pickProfileImage(context),
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFF0F4DAB),
                        child: Icon(Icons.edit, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            section("Personal Details", [
              field(nameCtrl, "Mechanic Name"),
              field(emailCtrl, "Email", readOnly: true),
              field(
                phoneCtrl,
                "Phone Number",
                keyboard: TextInputType.phone,
                validator: (v) =>
                    v != null && v.length == 10 ? null : "Enter 10 digits",
              ),
            ]),

            const SizedBox(height: 20),

            section("Workshop Details", [
              input(workshopCtrl, "Workshop Name"),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: locationDisplayCtrl, // ✅ CONTROLLER
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Workshop Location",
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.location_on),
                      onPressed: fetchLocationOnIconClick, // 📍 CLICK ACTION
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              input(
                expCtrl,
                "Experience (Years)",
                keyboard: TextInputType.number,
              ),
              input(kmCtrl, "Availability KM", keyboard: TextInputType.number),
            ]),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: saving ? null : () => saveProfile(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4DAB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Save Changes",
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HELPERS =================
  Widget input(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget section(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

Widget field(
  TextEditingController controller,
  String label, {
  bool readOnly = false,
  TextInputType keyboard = TextInputType.text,
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}
