import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/AddVehicle_Screen.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/VehicleDetailScreen.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/notification_service.dart';
import 'package:vehicle_maintance/MainScreens/bottom_menu.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  List<Map<String, dynamic>> vehicles = [];

  @override
  void initState() {
    super.initState();
    loadVehicles();
  }

  // ---------------- SET PRIMARY VEHICLE ----------------
  Future<void> setPrimaryVehicle(String selectedVehicleId, int index) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 🔴 CLEAR OLD PRIMARY
      await Supabase.instance.client
          .from('vehicles')
          .update({'is_primary': false})
          .eq('user_id', user.id);

      // 🟢 SET NEW PRIMARY
      await Supabase.instance.client
          .from('vehicles')
          .update({'is_primary': true})
          .eq('id', selectedVehicleId);

      // 🔵 UPDATE LOCAL LIST
      setState(() {
        final selected = vehicles.removeAt(index);
        vehicles.insert(0, selected);
      });

      await saveVehicles();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Primary vehicle updated")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to set primary: $e")));
    }
  }

  // ---------------- LOAD VEHICLES ----------------
  Future<void> loadVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString('vehicles');

    if (storedData != null) {
      final List decoded = jsonDecode(storedData);

      setState(() {
        vehicles = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      });

      // 🔁 MIGRATE OLD KEY → NEW KEY
      for (final v in vehicles) {
        if ((v["registration_number"] == null ||
                v["registration_number"].toString().isEmpty) &&
            v["number"] != null &&
            v["number"].toString().isNotEmpty) {
          v["registration_number"] = v["number"];
        }
      }

      // 🔔 CHECK INSURANCE ALERT LEVELS
      checkInsuranceAlerts();

      // 💾 SAVE MIGRATED DATA
      await saveVehicles();
    }
  }

  // ---------------- SAVE VEHICLES ----------------
  Future<void> saveVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vehicles', jsonEncode(vehicles));
  }

  // ---------------- ADD VEHICLE ----------------
  void addNewVehicle(Map<String, dynamic> data) {
    setState(() {
      vehicles.add({
        "id": data["id"],
        "type": data["type"] ?? "car",
        "brand": data["brand"] ?? "",
        "model": data["model"] ?? "",
        "registration_number":
            data["registration_number"] ?? data["number"] ?? "",

        "insurance": data["insurance"] ?? "Not set",

        // STORED (NOT DISPLAYED HERE)
        "mileage": data["mileage"]?.toString(),
        "year": data["year"],
        "vin": data["vin"],
        "puc": data["puc"],
        "insurance_expiry": data["insurance_expiry"],
        "rc_url": data["rc_url"],
        "insurance_url": data["insurance_url"],
      });
    });

    saveVehicles();
  }

  void checkInsuranceAlerts() {
    final now = DateTime.now();

    for (int i = 0; i < vehicles.length; i++) {
      final vehicle = vehicles[i];
      final expiryStr = vehicle["insurance_expiry"];

      if (expiryStr == null || expiryStr.toString().isEmpty) continue;

      final expiryDate = DateTime.tryParse(expiryStr);
      if (expiryDate == null) continue;

      final daysLeft = expiryDate.difference(now).inDays;

      final String name = "${vehicle["brand"] ?? ""} ${vehicle["model"] ?? ""}"
          .trim();

      // ❌ EXPIRED
      if (daysLeft < 0) {
        NotificationService.show(
          id: i,
          title: "❌ Insurance Expired",
          body: "$name insurance has expired. Renew immediately.",
        );
      }
      // 🔔 URGENT (≤ 3 DAYS)
      else if (daysLeft <= 3) {
        NotificationService.show(
          id: i,
          title: "🔔 Insurance Expiring Soon",
          body: "$name insurance expires in $daysLeft day(s).",
        );
      }
      // ⚠️ WARNING (≤ 7 DAYS)
      else if (daysLeft <= 7) {
        NotificationService.show(
          id: i,
          title: "⚠️ Insurance Reminder",
          body: "$name insurance expires in $daysLeft days.",
        );
      }
    }
  }

  // ---------------- DELETE VEHICLE ----------------
  Future<void> deleteVehicle(int index) async {
    if (index == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Primary vehicle cannot be deleted")),
      );
      return;
    }

    final vehicle = vehicles[index];
    final String? vehicleId = vehicle["id"];

    if (vehicleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid vehicle ID")));
      return;
    }

    try {
      // 🔴 DELETE FROM SUPABASE
      await Supabase.instance.client
          .from('vehicles')
          .delete()
          .eq('id', vehicleId);

      // 🔵 DELETE FROM LOCAL STORAGE
      setState(() {
        vehicles.removeAt(index);
      });

      await saveVehicles();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vehicle deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
    }
  }

  String safe(dynamic v) =>
      v == null || v.toString().isEmpty ? "N/A" : v.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        title: const Text("Registered Vehicles"),
        centerTitle: true,
      ),
      body: vehicles.isEmpty
          ? const Center(child: Text("No vehicles added yet"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final item = vehicles[index];
                final bool isPrimary = index == 0;
                final String type = (item["type"] ?? "").toLowerCase();

                final IconData vehicleIcon = type == "bike"
                    ? Icons.two_wheeler
                    : Icons.directions_car;
                return Opacity(
                  opacity: isPrimary ? 0.6 : 1.0,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: isPrimary
                          ? null
                          : () async {
                              final updatedVehicle = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      VehicleDetailScreen(vehicle: item),
                                ),
                              );

                              if (updatedVehicle != null &&
                                  updatedVehicle is Map<String, dynamic>) {
                                setState(() {
                                  vehicles[index] = updatedVehicle;
                                });
                                saveVehicles();
                              }
                            },
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(vehicleIcon, color: Colors.blue),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isPrimary)
                                  const Text(
                                    "PRIMARY VEHICLE",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                Text(
                                  "${safe(item["brand"])} ${safe(item["model"])}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Reg No: ${safe(item["registration_number"] ?? item["number"])}",
                                ),
                                if (!isPrimary) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Insurance: ${safe(item["insurance"])}",
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isPrimary)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteVehicle(index),
                            ),
                        ],
                      ),
                    ),
                  ),
                );

                /*return GestureDetector(
                  onTap: () async {
                    final updatedVehicle = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VehicleDetailScreen(vehicle: item),
                      ),
                    );

                    if (updatedVehicle != null &&
                        updatedVehicle is Map<String, dynamic>) {
                      setState(() {
                        vehicles[index] = updatedVehicle;
                      });
                      saveVehicles();
                    }
                  },

                  child: Opacity(
                    opacity: isPrimary ? 0.6 : 1.0,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(vehicleIcon, color: Colors.blue),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isPrimary)
                                  const Text(
                                    "PRIMARY VEHICLE",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                Text(
                                  "${safe(item["brand"])} ${safe(item["model"])}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Reg No: ${safe(item["registration_number"] ?? item["number"])}",
                                ),

                                const SizedBox(height: 4),
                                if (!isPrimary) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Insurance: ${safe(item["insurance"])}",
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isPrimary)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteVehicle(index),
                            ),
                        ],
                      ),
                    ),
                  ),
                );*/
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddvehicleScreen()),
          );

          if (result != null) {
            addNewVehicle(Map<String, dynamic>.from(result));
          }
        },
      ),
      bottomNavigationBar: const BottomMenu(selectedIndex: 1),
    );
  }
}
