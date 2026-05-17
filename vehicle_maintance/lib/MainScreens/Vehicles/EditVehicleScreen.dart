import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/verification/insurance_upload_box.dart';

class EditVehicleScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const EditVehicleScreen({super.key, required this.vehicle});

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController mileageController;
  late TextEditingController yearController;
  late TextEditingController vinController;
  late TextEditingController insuranceController;
  late TextEditingController pucController;
  late TextEditingController modelController;

  String? insuranceCopyUrl;
  String? insuranceOcrText;
  String? insuranceStatus;

  @override
  void initState() {
    super.initState();

    insuranceCopyUrl = widget.vehicle["insurance_copy_url"];

    // DEBUG: verify vehicle id
    debugPrint("EDIT VEHICLE ID => ${widget.vehicle["id"]}");

    mileageController = TextEditingController(
      text: widget.vehicle["mileage"]?.toString(),
    );

    yearController = TextEditingController(
      text: widget.vehicle["year"]?.toString(),
    );

    vinController = TextEditingController(
      text: widget.vehicle["vin_number"]?.toString(),
    );

    insuranceController = TextEditingController(
      text: widget.vehicle["insurance"]?.toString(),
    );

    pucController = TextEditingController(
      text: widget.vehicle["puc"]?.toString(),
    );

    modelController = TextEditingController(
      text: widget.vehicle["model"]?.toString(),
    );
  }

  @override
  void dispose() {
    mileageController.dispose();
    yearController.dispose();
    vinController.dispose();
    insuranceController.dispose();
    pucController.dispose();
    modelController.dispose();
    super.dispose();
  }

  // ================= DATE HELPERS =================
  String? _toSupabaseDate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final parsed = DateFormat('MM/dd/yy').parse(text);
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );

    if (picked != null) {
      controller.text = DateFormat('MM/dd/yy').format(picked);
    }
  }

  // ================= UPDATE VEHICLE =================
  Future<void> _updateVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final supabase = Supabase.instance.client;
    final vehicleId = widget.vehicle["id"];

    if (vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vehicle ID missing. Update not possible."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Map<String, dynamic> updates = {};

    void addIfChanged(String key, dynamic newValue, dynamic oldValue) {
      if (newValue == null) return;

      final newStr = newValue.toString().trim();
      final oldStr = oldValue?.toString().trim() ?? "";

      if (newStr.isNotEmpty && newStr != oldStr) {
        updates[key] = newValue;
      }
    }

    // NUMERIC FIELDS
    addIfChanged(
      "mileage",
      double.tryParse(mileageController.text),
      widget.vehicle["mileage"],
    );

    addIfChanged(
      "year",
      int.tryParse(yearController.text),
      widget.vehicle["year"],
    );

    // TEXT FIELDS
    addIfChanged("model", modelController.text.trim(), widget.vehicle["model"]);

    addIfChanged(
      "vin_number",
      vinController.text.trim().isEmpty ? null : vinController.text.trim(),
      widget.vehicle["vin_number"],
    );

    // DATE FIELDS
    final insuranceDate = _toSupabaseDate(insuranceController.text);
    if (insuranceDate != null) {
      addIfChanged(
        "insurance_expiry",
        insuranceDate,
        widget.vehicle["insurance"],
      );
    }

    final pucDate = _toSupabaseDate(pucController.text);
    if (pucDate != null) {
      addIfChanged("puc_expiry", pucDate, widget.vehicle["puc"]);
    }

    // FILE URL
    addIfChanged(
      "insurance_copy_url",
      insuranceCopyUrl,
      widget.vehicle["insurance_copy_url"],
    );

    if (updates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No changes to update")));
      return;
    }

    try {
      await supabase.from("vehicles").update(updates).eq("id", vehicleId);

      Navigator.pop(context, {
        if (updates.containsKey("mileage"))
          "mileage": mileageController.text.trim(),
        if (updates.containsKey("year")) "year": yearController.text.trim(),
        if (updates.containsKey("model")) "model": modelController.text.trim(),
        if (updates.containsKey("vin_number")) "vin": vinController.text.trim(),
        if (updates.containsKey("insurance_expiry"))
          "insurance": insuranceController.text.trim(),
        if (updates.containsKey("puc_expiry")) "puc": pucController.text.trim(),
        if (updates.containsKey("insurance_copy_url"))
          "insurance_copy_url": insuranceCopyUrl,
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update failed: $e")));
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Vehicle"),
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _field("Model", modelController),
              _numberField("Mileage", mileageController),
              _numberField("Year", yearController),
              _field("VIN Number", vinController),

              _dateField(
                "Insurance Expiry",
                insuranceController,
                () => _pickDate(insuranceController),
              ),

              _dateField(
                "PUC Expiry",
                pucController,
                () => _pickDate(pucController),
              ),

              const SizedBox(height: 24),

              InsuranceUploadBox(
                title: "Insurance Copy (Image / PDF)",
                folder: "insurance_copy",
                initialUrl: insuranceCopyUrl,
                onCompleted: (url, text, status) {
                  setState(() {
                    insuranceCopyUrl = url;
                    insuranceOcrText = text;
                    insuranceStatus = status;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Insurance uploaded successfully"),
                    ),
                  );
                },
              ),

              if (insuranceCopyUrl != null && insuranceCopyUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.verified, color: Colors.green, size: 18),
                      SizedBox(width: 6),
                      Text(
                        "Insurance already uploaded",
                        style: TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _updateVehicle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4DAB),
                  ),
                  child: const Text(
                    "Update",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= FIELD HELPERS =================
  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _numberField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dateField(String label, TextEditingController c, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        readOnly: true,
        decoration: InputDecoration(labelText: label),
        onTap: onTap,
      ),
    );
  }
}
