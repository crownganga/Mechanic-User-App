import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_maintance/MainScreens/Maintance/vehiclemaintenance_details.dart';
import 'package:vehicle_maintance/MainScreens/bottom_menu.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  List vehicles = [];

  @override
  void initState() {
    super.initState();
    fetchVehicles();
  }

  Future<void> fetchVehicles() async {
    final res = await supabase
        .from('vehicles')
        .select('id, brand, model, registration_number, vehicle_type');

    setState(() {
      vehicles = res;
      loading = false;
    });
  }

  IconData getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        title: const Text("Maintenance "),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final v = vehicles[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: Icon(
                      getVehicleIcon(v['vehicle_type']),
                      size: 36,
                      color: Colors.blue,
                    ),
                    title: Text(
                      "${v['brand']} ${v['model']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      v['registration_number'],
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VehicleMaintenanceUIScreen(
                            vehicleId: v['id'],
                            brand: v['brand'],
                            model: v['model'],
                            vehicleType: v['vehicle_type'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: const BottomMenu(selectedIndex: 3),
    );
  }
}
