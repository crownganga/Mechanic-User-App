import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_maintance/MainScreens/Maintance/booking_service_screen.dart';
import 'edit_vehicle_maintenance_screen.dart';

class VehicleMaintenanceUIScreen extends StatefulWidget {
  final String vehicleId;
  final String brand;
  final String model;
  final String vehicleType;

  const VehicleMaintenanceUIScreen({
    super.key,
    required this.vehicleId,
    required this.brand,
    required this.model,
    required this.vehicleType,
  });

  @override
  State<VehicleMaintenanceUIScreen> createState() =>
      _VehicleMaintenanceUIScreenState();
}

class _VehicleMaintenanceUIScreenState
    extends State<VehicleMaintenanceUIScreen> {
  // ================= STATE =================
  bool loading = true;

  double currentMileage = 0;
  double engineOilDueKm = 0;
  double generalServiceDueKm = 0;
  double brakeCheckDueKm = 0;

  final supabase = Supabase.instance.client;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    fetchVehicleMaintenance();
  }

  // ================= STATUS LOGIC =================
  Map<String, dynamic> getServiceStatus(double mileage, double dueKm) {
    if (dueKm == 0) {
      return {'text': 'No Data', 'color': Colors.grey};
    }

    final remainingKm = dueKm - mileage;

    if (remainingKm <= 0) {
      return {'text': 'Overdue', 'color': Colors.red};
    } else if (remainingKm <= 1000) {
      return {'text': 'Service Soon', 'color': Colors.orange};
    } else {
      return {'text': 'Good', 'color': Colors.green};
    }
  }

  // ================= FETCH DATA =================
  Future<void> fetchVehicleMaintenance() async {
    final res = await supabase
        .from('vehicles')
        .select(
          'mileage, engine_oil_due_km, general_service_due_km, brake_check_due_km',
        )
        .eq('id', widget.vehicleId)
        .single();

    setState(() {
      currentMileage = (res['mileage'] ?? 0).toDouble();
      engineOilDueKm = (res['engine_oil_due_km'] ?? 0).toDouble();
      generalServiceDueKm = (res['general_service_due_km'] ?? 0).toDouble();
      brakeCheckDueKm = (res['brake_check_due_km'] ?? 0).toDouble();
      loading = false;
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),

      // -------- APP BAR --------
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Row(
          children: [
            Icon(
              widget.vehicleType.toLowerCase() == 'bike'
                  ? Icons.motorcycle
                  : Icons.directions_car,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              "${widget.brand} ${widget.model}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditVehicleMaintenanceScreen(
                    vehicleId: widget.vehicleId,
                    currentMileage: currentMileage,
                    engineOilDueKm: engineOilDueKm,
                    generalServiceDueKm: generalServiceDueKm,
                    brakeCheckDueKm: brakeCheckDueKm,
                  ),
                ),
              );

              if (updated == true) {
                fetchVehicleMaintenance();
              }
            },
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text("Edit", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),

      // -------- BODY --------
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow("Vehicle", "${widget.brand} ${widget.model}"),
                  const SizedBox(height: 6),
                  _infoRow("Current Mileage", "$currentMileage km"),
                  const SizedBox(height: 16),

                  _serviceCard(
                    title: "Engine Oil Service",
                    dueKm: engineOilDueKm,
                  ),

                  _serviceCard(
                    title: "General Service",
                    dueKm: generalServiceDueKm,
                  ),

                  _serviceCard(title: "Brake Check", dueKm: brakeCheckDueKm),

                  const SizedBox(height: 24),

                  // -------- BOOK SERVICE BUTTON --------
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingServiceScreen(
                              vehicleId:
                                  widget.vehicleId, // ✅ PASS CURRENT VEHICLE ID
                            ),
                          ),
                        );
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F4DAB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Book Service",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ================= HELPERS =================
  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(fontSize: 15, color: Colors.black54),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _serviceCard({required String title, required double dueKm}) {
    final status = getServiceStatus(currentMileage, dueKm);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Next Due: ${dueKm == 0 ? '--' : '$dueKm'} km"),
              Row(
                children: [
                  Icon(Icons.circle, size: 10, color: status['color']),
                  const SizedBox(width: 6),
                  Text(
                    status['text'],
                    style: TextStyle(
                      color: status['color'],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
