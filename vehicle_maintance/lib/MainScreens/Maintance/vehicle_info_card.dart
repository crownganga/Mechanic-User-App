import 'package:flutter/material.dart';

class VehicleInfoCard extends StatelessWidget {
  const VehicleInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const ListTile(
        leading: Icon(Icons.speed, color: Colors.blue),
        title: Text(
          "Vehicle & Mileage",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("Current Mileage: -- km"),
      ),
    );
  }
}
