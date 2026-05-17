import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditVehicleMaintenanceScreen extends StatefulWidget {
  final String vehicleId;
  final double currentMileage;
  final double engineOilDueKm;
  final double generalServiceDueKm;
  final double brakeCheckDueKm;

  const EditVehicleMaintenanceScreen({
    super.key,
    required this.vehicleId,
    required this.currentMileage,
    required this.engineOilDueKm,
    required this.generalServiceDueKm,
    required this.brakeCheckDueKm,
  });

  @override
  State<EditVehicleMaintenanceScreen> createState() =>
      _EditVehicleMaintenanceScreenState();
}

class _EditVehicleMaintenanceScreenState
    extends State<EditVehicleMaintenanceScreen> {
  final supabase = Supabase.instance.client;

  late TextEditingController mileageCtrl;
  late TextEditingController engineOilCtrl;
  late TextEditingController generalServiceCtrl;
  late TextEditingController brakeCheckCtrl;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    mileageCtrl = TextEditingController(text: widget.currentMileage.toString());
    engineOilCtrl = TextEditingController(
      text: widget.engineOilDueKm.toString(),
    );
    generalServiceCtrl = TextEditingController(
      text: widget.generalServiceDueKm.toString(),
    );
    brakeCheckCtrl = TextEditingController(
      text: widget.brakeCheckDueKm.toString(),
    );
  }

  /// ✅ UPDATE ALL MAINTENANCE DATA
  Future<void> saveAllDetails() async {
    setState(() => saving = true);

    await supabase
        .from('vehicles')
        .update({
          'mileage': double.parse(mileageCtrl.text),
          'engine_oil_due_km': double.parse(engineOilCtrl.text),
          'general_service_due_km': double.parse(generalServiceCtrl.text),
          'brake_check_due_km': double.parse(brakeCheckCtrl.text),
        })
        .eq('id', widget.vehicleId);

    setState(() => saving = false);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        title: const Text("Edit Maintenance Details"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label("Current Mileage"),
            _numberField(mileageCtrl),

            const SizedBox(height: 16),
            _label("Engine Oil Service – Next Due (km)"),
            _numberField(engineOilCtrl),

            const SizedBox(height: 16),
            _label("General Service – Next Due (km)"),
            _numberField(generalServiceCtrl),

            const SizedBox(height: 16),
            _label("Brake Check – Next Due (km)"),
            _numberField(brakeCheckCtrl),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: saving ? null : saveAllDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: saving
                      ? Colors.grey
                      : const Color(0xFF0F4DAB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "Save Changes",
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

  // 🔹 UI HELPERS

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  Widget _numberField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          suffixText: "km",
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
