import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VehicleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  String safe(dynamic v) {
    if (v == null) return "N/A";
    if (v.toString().trim().isEmpty) return "N/A";
    return v.toString();
  }

  String formatDate(dynamic date) {
    if (date == null) return "N/A";
    try {
      final parsed = DateTime.parse(date.toString());
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return "N/A";
    }
  }

  Widget field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        title: const Text("Vehicle Details"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field("Registration No", safe(vehicle['registration_number'])),

              field("Vehicle Type", safe(vehicle['vehicle_type'])),

              field("Brand", safe(vehicle['brand'])),

              field("Model", safe(vehicle['model'])),

              field("Year", safe(vehicle['year'])),

              field("Fuel Type", safe(vehicle['fuel_type'])),

              field("Mileage", safe(vehicle['mileage'])),

              field("VIN Number", safe(vehicle['vin_number'])),

              field(
                "Insurance Expiry",
                formatDate(vehicle['insurance_expiry']),
              ),

              field("PUC Expiry", formatDate(vehicle['puc_expiry'])),
            ],
          ),
        ),
      ),
    );
  }
}
