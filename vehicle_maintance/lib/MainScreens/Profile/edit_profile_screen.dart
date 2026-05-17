import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_maintance/MainScreens/Profile/profile_screen.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/verification/insurance_upload_box.dart';

class EditprofileScreen extends StatefulWidget {
  const EditprofileScreen({super.key});

  @override
  State<EditprofileScreen> createState() => _EditprofileScreenState();
}

class _EditprofileScreenState extends State<EditprofileScreen> {
  bool _isSaving = false;

  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();

  String? insuranceUrl;
  String? oldInsuranceUrl;
  bool insuranceUpdated = false;

  String? insuranceCopyUrl;

  File? selectedImage;
  String? profileImageUrl;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final locationCtrl = TextEditingController();

  final regNoCtrl = TextEditingController();
  final typeCtrl = TextEditingController();
  final brandCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final yearCtrl = TextEditingController();
  final fuelCtrl = TextEditingController();
  final mileageCtrl = TextEditingController();
  final vinCtrl = TextEditingController();

  DateTime? insuranceExpiry;
  DateTime? pucExpiry;

  String? vehicleId;
  String? rcUrl;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ================= LOAD DATA =================
  Future<void> loadData() async {
    final user = supabase.auth.currentUser!;
    emailCtrl.text = user.email ?? "";

    final userRes = await supabase
        .from('users_data')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (userRes != null) {
      nameCtrl.text = userRes['name'] ?? "";
      phoneCtrl.text = userRes['phone'] ?? "";
      locationCtrl.text = userRes['location'] ?? "";
      profileImageUrl = userRes['profile_image_url'];
    }

    final vehicleRes = await supabase
        .from('vehicles')
        .select()
        .eq('user_id', user.id)
        .eq('is_primary', true)
        .maybeSingle();

    if (vehicleRes != null) {
      vehicleId = vehicleRes['id'];
      regNoCtrl.text = vehicleRes['registration_number'] ?? "";
      typeCtrl.text = vehicleRes['vehicle_type'] ?? "";
      brandCtrl.text = vehicleRes['brand'] ?? "";
      modelCtrl.text = vehicleRes['model'] ?? "";
      yearCtrl.text = vehicleRes['year']?.toString() ?? "";
      fuelCtrl.text = vehicleRes['fuel_type'] ?? "";
      mileageCtrl.text = vehicleRes['mileage']?.toString() ?? "";
      vinCtrl.text = vehicleRes['vin_number'] ?? "";

      insuranceExpiry = vehicleRes['insurance_expiry'] != null
          ? DateTime.parse(vehicleRes['insurance_expiry'])
          : null;

      pucExpiry = vehicleRes['puc_expiry'] != null
          ? DateTime.parse(vehicleRes['puc_expiry'])
          : null;

      rcUrl = vehicleRes['rc_book_url'];
      insuranceUrl = vehicleRes['insurance_copy_url'];
      oldInsuranceUrl = insuranceUrl;

      insuranceUrl = vehicleRes['insurance_copy_url'];
      insuranceCopyUrl = insuranceUrl; // ✅ THIS LINE IS REQUIRED
      oldInsuranceUrl = insuranceUrl;
    }

    setState(() {});
  }

  // ================= PROFILE IMAGE UPLOAD =================
  Future<void> pickAndUploadProfileImage(BuildContext ctx) async {
    try {
      final user = supabase.auth.currentUser!;
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      final file = File(image.path);
      final fileName = "${user.id}${extension(image.path)}";

      await supabase.storage
          .from('profile_images')
          .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

      // 🔥 ADD TIMESTAMP TO FORCE IMAGE REFRESH
      final imageUrl =
          '${supabase.storage.from('profile_images').getPublicUrl(fileName)}?t=${DateTime.now().millisecondsSinceEpoch}';

      if (!mounted) return;

      setState(() {
        selectedImage = file;
        profileImageUrl = imageUrl;
      });

      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text("Profile image updated")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text("Image upload failed: $e")));
    }
  }

  // ================= DATE PICKER =================
  Future<void> pickDate(BuildContext ctx, bool isInsurance) async {
    //   final BuildContext ctx = context; // 🔥 force correct type

    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      isInsurance ? insuranceExpiry = picked : pucExpiry = picked;
    });
  }

  // ================= SAVE =================
  Future<void> saveAll(BuildContext ctx) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser!;
      final String vid = vehicleId!;

      // ---- USER UPDATE
      await supabase
          .from('users_data')
          .update({
            'name': nameCtrl.text.trim(),
            'phone': phoneCtrl.text.trim(),
            'location': locationCtrl.text.trim(),
            if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
          })
          .eq('user_id', user.id);

      // ---- VEHICLE UPDATE
      if (vehicleId == null) {
        throw Exception("Vehicle ID not found");
      }
      await supabase
          .from('vehicles')
          .update({
            'registration_number': regNoCtrl.text.trim(),
            'vehicle_type': typeCtrl.text.trim(),
            'brand': brandCtrl.text.trim(),
            'model': modelCtrl.text.trim(),
            'year': int.tryParse(yearCtrl.text),
            'fuel_type': fuelCtrl.text.trim(),
            'mileage': double.tryParse(mileageCtrl.text),
            'vin_number': vinCtrl.text.trim().isEmpty
                ? null
                : vinCtrl.text.trim(),
            'insurance_expiry': insuranceExpiry?.toIso8601String().substring(
              0,
              10,
            ),
            'puc_expiry': pucExpiry?.toIso8601String().substring(0, 10),
            'insurance_copy_url': insuranceCopyUrl,
          })
          .eq('id', vehicleId!)
          .eq('user_id', user.id);

      if (!mounted) return;

      // ✅ SUCCESS MESSAGE
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text("Profile updated successfully"),
          backgroundColor: Colors.green,
        ),
      );

      // ⏳ small delay so user sees snackbar
      await Future.delayed(const Duration(milliseconds: 800));

      // ✅ GO TO PROFILE PAGE
      Navigator.pushReplacement(
        ctx,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text("Failed to save profile: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
            // ================= PROFILE IMAGE =================
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: selectedImage != null
                        ? FileImage(selectedImage!)
                        : profileImageUrl != null
                        ? NetworkImage(profileImageUrl!)
                        : const AssetImage("assets/user.png") as ImageProvider,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => pickAndUploadProfileImage(context),

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

            // ================= PERSONAL DETAILS =================
            sectionCard(
              title: "Personal Details",
              children: [
                field(nameCtrl, "Full Name"),
                field(emailCtrl, "Email", readOnly: true),
                field(
                  phoneCtrl,
                  "Phone Number",
                  keyboard: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (v.length != 10) return "Enter 10 digit phone";
                    return null;
                  },
                ),
                field(locationCtrl, "Location"),
              ],
            ),

            const SizedBox(height: 20),

            // ================= VEHICLE DETAILS =================
            sectionCard(
              title: "Vehicle Details",
              children: [
                field(regNoCtrl, "Registration Number"),
                field(typeCtrl, "Vehicle Type"),
                field(fuelCtrl, "Fuel Type"),
                field(brandCtrl, "Brand"),
                field(modelCtrl, "Model"),
                field(yearCtrl, "Year", keyboard: TextInputType.number),
                field(mileageCtrl, "Mileage"),
                field(
                  vinCtrl,
                  "VIN Number (Optional)",
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (v.length != 17) return "VIN must be 17 characters";
                    return null;
                  },
                ),

                const SizedBox(height: 10),

                dateTile(
                  "Insurance Expiry Date",
                  insuranceExpiry,
                  () => pickDate(context, true),
                ),
                dateTile(
                  "PUC Expiry Date",
                  pucExpiry,
                  () => pickDate(context, false),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ================= DOCUMENTS =================
            sectionCard(
              title: "Vehicle Documents",
              children: [
                // ✅ SHOW STATUS TEXT IF ALREADY UPLOADED
                if (insuranceCopyUrl != null && insuranceCopyUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "Insurance uploaded",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                InsuranceUploadBox(
                  title: "Insurance Copy (Image / PDF)",
                  folder: "insurance_copy",
                  initialUrl: insuranceCopyUrl,
                  onCompleted: (url, text, status) {
                    setState(() {
                      insuranceCopyUrl = url;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ================= SAVE BUTTON =================
            ElevatedButton(
              onPressed: _isSaving ? null : () => saveAll(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4DAB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Save Changes", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- HELPERS
  Widget field(
    TextEditingController c,
    String label, {
    bool readOnly = false,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        readOnly: readOnly,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget dateTile(String label, DateTime? date, VoidCallback onTap) {
    return ListTile(
      title: Text(label),
      subtitle: Text(
        date == null ? "Select date" : DateFormat('dd-MM-yyyy').format(date),
      ),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
    );
  }
}

Widget sectionCard({required String title, required List<Widget> children}) {
  return Card(
    elevation: 2,
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

Widget field(
  TextEditingController c,
  String label, {
  bool readOnly = false,
  TextInputType keyboard = TextInputType.text,
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
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

Widget dateTile(String label, DateTime? date, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                date == null
                    ? "Select date"
                    : DateFormat('dd-MM-yyyy').format(date),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const Icon(Icons.calendar_today, size: 20),
        ],
      ),
    ),
  );
}

/*
Widget sectionCard({required String title, required List<Widget> children}) {
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

Widget field(
  TextEditingController c,
  String label, {
  bool readOnly = false,
  TextInputType keyboard = TextInputType.text,
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
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

Widget dateTile(String label, DateTime? date, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                date == null
                    ? "Select date"
                    : DateFormat('dd-MM-yyyy').format(date),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const Icon(Icons.calendar_today, size: 20),
        ],
      ),
    ),
  );
}

Widget uploadStatus(String label, String? url) {
  final bool uploaded = url != null && url.isNotEmpty;

  return Row(
    children: [
      Icon(
        uploaded ? Icons.check_circle : Icons.cancel,
        color: uploaded ? Colors.green : Colors.red,
        size: 18,
      ),
      const SizedBox(width: 6),
      Text(
        uploaded ? "$label Uploaded" : "$label Not Uploaded",
        style: TextStyle(
          color: uploaded ? Colors.green : Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

Widget insuranceUploadStatus() {
  if (insuranceUrl == null || insuranceUrl!.isEmpty) {
    return _statusRow(
      icon: Icons.cancel,
      color: Colors.red,
      text: "Insurance Copy Not Uploaded",
    );
  }

  if (insuranceUpdated) {
    return _statusRow(
      icon: Icons.autorenew,
      color: Colors.orange,
      text: "Insurance Copy Updated (New)",
    );
  }

  return _statusRow(
    icon: Icons.check_circle,
    color: Colors.green,
    text: "Insurance Copy Uploaded",
  );
}

Widget _statusRow({
  required IconData icon,
  required Color color,
  required String text,
}) {
  return Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 6),
      Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    ],
  );
}*/
