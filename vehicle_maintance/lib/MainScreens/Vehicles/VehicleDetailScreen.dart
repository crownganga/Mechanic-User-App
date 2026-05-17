import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/EditVehicleScreen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? vehicleData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchVehicle();
  }

  /// 🔥 FETCH FULL VEHICLE DATA
  Future<void> fetchVehicle() async {
    final data = await supabase
        .from('vehicles')
        .select('*')
        .eq('id', widget.vehicle['id'])
        .single();

    setState(() {
      vehicleData = data;
      loading = false;
    });

    debugPrint("FULL VEHICLE DATA => $data");
  }

  /// 🌐 OPEN FILE IN BROWSER
  Future<void> openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not open document';
    }
  }

  String _safeValue(dynamic value) {
    if (value == null) return "N/A";
    if (value is num) return value.toString();
    if (value.toString().trim().isEmpty) return "N/A";
    return value.toString();
  }

  bool _hasFile(dynamic url) {
    return url != null && url.toString().trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _safeValue(vehicleData!["brand"]),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _readOnlyField(
              "Vehicle Type",
              _safeValue(vehicleData!["vehicle_type"]),
            ),
            _readOnlyField("Brand", _safeValue(vehicleData!["brand"])),
            _readOnlyField("Model", _safeValue(vehicleData!["model"])),
            _readOnlyField(
              "Registration No",
              _safeValue(vehicleData!["registration_number"]),
            ),
            _readOnlyField("Year", _safeValue(vehicleData!["year"])),
            _readOnlyField("Mileage", _safeValue(vehicleData!["mileage"])),
            _readOnlyField(
              "Insurance Expiry",
              _safeValue(vehicleData!["insurance_expiry"]),
            ),
            _readOnlyField(
              "VIN Number",
              _safeValue(vehicleData!["vin_number"]),
            ),
            _readOnlyField(
              "PUC Expiry",
              _safeValue(vehicleData!["puc_expiry"]),
            ),

            const SizedBox(height: 24),

            /// 📘 RC BOOK
            if (_hasFile(vehicleData!['rc_book_url']))
              _fileTile(
                title: "RC Book",
                icon: Icons.description,
                onTap: () => openInBrowser(vehicleData!['rc_book_url']),
              )
            else
              _notUploadedTile("RC Book"),

            const SizedBox(height: 14),

            /// 🛡️ INSURANCE COPY
            if (_hasFile(vehicleData!['insurance_copy_url']))
              _fileTile(
                title: "Insurance Copy",
                icon: Icons.verified_user,
                onTap: () => openInBrowser(vehicleData!['insurance_copy_url']),
              )
            else
              _notUploadedTile("Insurance Copy"),
          ],
        ),
      ),

      /// ✏️ EDIT BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F4DAB),
        child: const Icon(Icons.edit, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditVehicleScreen(
                vehicle: Map<String, dynamic>.from(vehicleData!),
              ),
            ),
          );

          if (result != null && result is Map<String, dynamic>) {
            setState(() {
              vehicleData!.addAll(result);
            });

            // 🔥 SEND UPDATED VEHICLE BACK TO VEHICLE SCREEN
            Navigator.pop(context, vehicleData);
          }
        },
      ),
    );
  }

  /// 🔒 READ-ONLY FIELD
  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  /// 📂 FILE TILE
  Widget _fileTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF0F4DAB)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    );
  }

  /// ⚠️ NOT UPLOADED TILE
  Widget _notUploadedTile(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.grey),
          const SizedBox(width: 14),
          Text(
            "$title not uploaded",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
