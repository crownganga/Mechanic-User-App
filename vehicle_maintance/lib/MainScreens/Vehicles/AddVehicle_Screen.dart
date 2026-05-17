import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
//import 'package:vehicle_maintance/MainScreens/Vehicles/vehicle_screen.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/verification/insurance_upload_box.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/verification/rc_upload_box.dart';

class AddvehicleScreen extends StatefulWidget {
  const AddvehicleScreen({super.key});

  @override
  State<AddvehicleScreen> createState() => _AddvehicleScreenState();
}

class _AddvehicleScreenState extends State<AddvehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleTypeController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _regNoController = TextEditingController();
  final _insuranceExpiryController = TextEditingController();
  final _pucExpiryController = TextEditingController();
  final _fuelController = TextEditingController();
  final _mileageController = TextEditingController();
  final _vinController = TextEditingController();
  final RegExp vinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

  bool allowUpload = false;
  bool allowInsuranceUpload = false;
  bool get isFormReady {
    return rcBookUrl != null && insuranceCopyUrl != null;
  }

  String? rcBookUrl;
  String rcBookText = "";
  String rcBookStatus = "";

  String? insuranceCopyUrl;
  String insuranceCopyText = "";
  String insuranceCopyStatus = "";

  String selectedType = "car"; // default value

  // DateTime? _insuranceExpiryDate;
  //DateTime? _pucExpiryDate;

  String? parseToSupabaseDate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final parsed = DateFormat('MM/dd/yy').parse(text.trim());
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (e) {
      return null;
    }
  }

  final Map<String, List<String>> vehicleTypeBrands = {
    'Car': [
      'Maruti Suzuki',
      'Hyundai',
      'Tata',
      'Mahindra',
      'Toyota',
      'Honda',
      'Kia',
      'Volkswagen',
      'Renault',
      'Nissan',
      'BMW',
      'Audi',
    ],
    'Bike - auto gear': ['Honda', 'TVS', 'Yamaha', 'Suzuki', 'Royal Enfield'],
    'Bike - without gear': ['Bajaj', 'Hero', 'TVS'],
  };

  final Map<String, List<String>> vehicleTypeFuels = {
    'Car': ['Petrol', 'Diesel', 'Electric', 'CNG', 'Hybrid'],
    'Bike - auto gear': ['Petrol', 'Electric'],
    'Bike - without gear': ['Petrol'],
  };

  final RegExp regNoPattern = RegExp(
    r'^[A-Z]{2}[ -]?[0-9]{1,2}[ -]?[A-Z]{1,2}[ -]?[0-9]{4}$',
  );

  Future<void> _pickInsuranceExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), // cannot pick past dates
      lastDate: DateTime(2050),
    );

    if (picked != null) {
      setState(() {
        _insuranceExpiryController.text = DateFormat('MM/dd/yy').format(picked);
      });
    }
  }

  Future<void> _pickPucExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );

    if (picked != null) {
      setState(() {
        _pucExpiryController.text = DateFormat('MM/dd/yy').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Processing...")));

    final supabase = Supabase.instance.client;
    final uuid = const Uuid();

    final String id = uuid.v4();
    final String? userId = supabase.auth.currentUser?.id;

    // 🔴 Login check
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in")));
      return;
    }

    // 🔴 Required uploads check
    if (rcBookUrl == null || insuranceCopyUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload both RC & Insurance")),
      );
      return;
    }

    // 🔴 Vehicle type check (VERY IMPORTANT)
    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select vehicle type")),
      );
      return;
    }
    // 🔍 CHECK IF PRIMARY VEHICLE ALREADY EXISTS
    final existingPrimary = await supabase
        .from('vehicles')
        .select('id')
        .eq('user_id', userId)
        .eq('is_primary', true)
        .maybeSingle();

    // 👉 if no primary exists, this one becomes primary
    final bool makePrimary = existingPrimary == null;

    // ✅ Prepare Supabase data
    final Map<String, dynamic> dataToInsert = {
      'id': id,
      'user_id': userId,
      'vehicle_type': selectedType.toLowerCase(),
      'fuel_type': _fuelController.text.trim(),
      'brand': _brandController.text.trim(),
      'model': _modelController.text.trim(),
      'mileage': double.tryParse(_mileageController.text.trim()),
      'vin_number': _vinController.text.trim().isEmpty
          ? null
          : _vinController.text.trim(),
      'year': int.tryParse(_yearController.text.trim()),
      'registration_number': _regNoController.text.trim(),
      'insurance_expiry': parseToSupabaseDate(_insuranceExpiryController.text),
      'puc_expiry': parseToSupabaseDate(_pucExpiryController.text),
      'rc_book_url': rcBookUrl,
      'insurance_copy_url': insuranceCopyUrl,
      'created_at': DateTime.now().toIso8601String(),

      // ⭐⭐⭐ THIS IS THE FIX ⭐⭐⭐
      'is_primary': makePrimary,
    };

    try {
      // ✅ Insert into Supabase
      await supabase.from('vehicles').insert(dataToInsert);

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vehicle Registered Successfully"),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ RETURN DATA SAFELY TO VEHICLE SCREEN
      Navigator.pop(context, {
        "id": id,
        "type": selectedType, // 🔥 "bike" or "car"

        "brand": _brandController.text,
        "model": _modelController.text,
        "number": _regNoController.text,
        "insurance": _insuranceExpiryController.text,

        // ✅ FIX IS HERE
        "year": int.tryParse(_yearController.text.trim()),
        "mileage": _mileageController.text.trim(),

        // optional
        "vin": _vinController.text.trim(),
        "puc": _pucExpiryController.text.trim(),
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Submission Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Vehicle"),
        backgroundColor: const Color.fromARGB(255, 15, 77, 171),
        foregroundColor: Colors.white, // <-- MAKES TITLE & ICONS WHITE
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _regNoController,
                decoration: const InputDecoration(
                  labelText: "Registration Number",
                  hintText: "e.g., TN 45 AB 1234",
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Registration Number is required";
                  }

                  final formatted = value.toUpperCase().trim();

                  if (!regNoPattern.hasMatch(formatted)) {
                    return "Invalid Reg Number (Use format like TN 45 AB 1234)";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField(
                decoration: const InputDecoration(labelText: "Vehicle Type"),
                items: vehicleTypeBrands.keys
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _vehicleTypeController.text = value!;
                    _brandController.clear();

                    // ✅ THIS LINE FIXES BIKE / CAR ICON
                    if (value.toString().toLowerCase().startsWith("bike")) {
                      selectedType = "bike";
                    } else {
                      selectedType = "car";
                    }
                  });
                },
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _fuelController.text.isEmpty
                    ? null
                    : _fuelController.text,
                decoration: const InputDecoration(labelText: "Fuel Type"),
                items:
                    (_vehicleTypeController.text.isEmpty
                            ? <String>[]
                            : vehicleTypeFuels[_vehicleTypeController.text]!)
                        .map(
                          (fuel) => DropdownMenuItem<String>(
                            value: fuel,
                            child: Text(fuel),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _fuelController.text = value ?? "";
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Fuel type is required";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),
              DropdownButtonFormField(
                decoration: const InputDecoration(labelText: "Brand"),
                items:
                    (_vehicleTypeController.text.isEmpty
                            ? []
                            : vehicleTypeBrands[_vehicleTypeController.text]!)
                        .map(
                          (brand) => DropdownMenuItem(
                            value: brand,
                            child: Text(brand),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() => _brandController.text = value.toString());
                },
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: "Model",
                  hintText: "e.g., Swift, Activa, Fortuner",
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Model is required";
                  }

                  if (value.trim().length < 2) {
                    return "Model name must be at least 2 characters";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _mileageController,
                decoration: const InputDecoration(
                  labelText: "Mileage",
                  hintText: "e.g., 18.5",
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Mileage is required";
                  }

                  final mileage = double.tryParse(value);
                  if (mileage == null || mileage <= 0 || mileage > 200) {
                    return "Enter valid mileage";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _vinController,
                decoration: const InputDecoration(
                  labelText: "VIN Number (Optional)",
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  if (value.length != 17) {
                    return "VIN must be 17 characters";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: "Year",
                  hintText: "e.g., 2020",
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Year is required";
                  }

                  final year = int.tryParse(value.trim());
                  final currentYear = DateTime.now().year;

                  if (year == null) {
                    return "Enter a valid numeric year";
                  }

                  if (value.trim().length != 4) {
                    return "Year must be 4 digits (e.g., 2022)";
                  }

                  if (year < 1900 || year > currentYear + 1) {
                    return "Enter a valid year between 1900 and ${currentYear + 1}";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _insuranceExpiryController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Insurance Expiry Date",
                  hintText: "Select expiry date",
                ),
                onTap: _pickInsuranceExpiryDate,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Insurance expiry date is required";
                  }

                  try {
                    final selectedDate = DateFormat(
                      "MM/dd/yy",
                    ).parse(value.trim());

                    final today = DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    );

                    if (selectedDate.isBefore(today)) {
                      return "Expiry date must be today or a future date";
                    }
                  } catch (e) {
                    return "Invalid date format. Use MM/DD/YY";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),
              TextFormField(
                controller: _pucExpiryController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "PUC Expiry Date (Optional)",
                  hintText: "Select expiry date",
                ),
                onTap: _pickPucExpiryDate,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null; // Optional → no validation if empty
                  }

                  try {
                    final selectedDate = DateFormat(
                      "MM/dd/yy",
                    ).parse(value.trim());

                    final today = DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    );

                    if (selectedDate.isBefore(today)) {
                      return "PUC expiry must be a future date";
                    }
                  } catch (e) {
                    return "Invalid date format. Use MM/DD/YY";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ================================
              // RC VERIFICATION + UPLOAD
              // ================================
              RCUploadBox(
                title: "RC Book (Image / PDF)",
                folder: "rc_book",
                onCompleted: (url, text, status) {
                  rcBookUrl = url;
                },
              ),

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

              const SizedBox(height: 20),

              // ================================
              // INSURANCE VERIFICATION + UPLOAD
              // ================================
              /*   InsuranceUploadBox(
                folder: "insurance_copy",
                onCompleted: (url, text, status) {
                  setState(() {
                    insuranceCopyUrl =
                        url; // REQUIRED for enabling Register button
                    insuranceCopyText = text;
                    insuranceCopyStatus = status;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Insurance Uploaded Successfully!"),
                    ),
                  );
                },
              ),*/
              const SizedBox(height: 20),

              // ================================
              // REGISTER BUTTON
              // ================================
              SizedBox(
                width: double.infinity,
                height: 56, // Increased height for better tap target
                child: ElevatedButton(
                  onPressed: isFormReady ? _submitForm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFormReady
                        ? const Color.fromARGB(255, 15, 77, 171)
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                  ),
                  child: const Text(
                    "Register",
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
      ),
    );
  }
}
