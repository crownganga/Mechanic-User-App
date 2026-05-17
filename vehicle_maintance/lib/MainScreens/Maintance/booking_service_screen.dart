import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class BookingServiceScreen extends StatefulWidget {
  final String vehicleId;

  const BookingServiceScreen({super.key, required this.vehicleId});

  @override
  State<BookingServiceScreen> createState() => _BookingServiceScreenState();
}

class _BookingServiceScreenState extends State<BookingServiceScreen> {
  final supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser!.id;

  GoogleMapController? mapController;
  LatLng? userLocation;
  Set<Marker> mechanicMarkers = {};

  Map<String, dynamic>? userData;
  Map<String, dynamic>? vehicleData;

  List<String> selectedServices = [];

  final TextEditingController descCtrl = TextEditingController();

  bool mechanicFree = false;
  bool checkingMechanic = true;
  String? selectedMechanicId;

  bool loading = true;
  bool submitting = false;

  final List<String> services = [
    'Engine Oil Service',
    'General Service',
    'Brake Check',
    'Other',
  ];

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();
    loadInitialData();
    checkMechanicAvailability();
    loadUserLocation(); // 🟢 ADD THIS
  }

  Future<void> loadUserLocation() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    userLocation = LatLng(pos.latitude, pos.longitude);

    await loadMechanicsOnMap();
  }

  Future<Map<String, String>?> findFreeSlot(
    String mechanicId,
    String workDate,
  ) async {
    // 1️⃣ Get mechanic schedule
    final schedule = await supabase
        .from('mechanic_work_schedule')
        .select('start_time, end_time')
        .eq('mechanic_id', mechanicId)
        .eq('work_date', workDate)
        .maybeSingle();

    if (schedule == null) return null;

    int toMin(String t) {
      final p = t.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    int start = toMin(schedule['start_time']);
    int end = toMin(schedule['end_time']);

    // 2️⃣ Get booked slots
    final booked = await supabase
        .from('service_requests_new')
        .select('slot_start, slot_end')
        .eq('mechanic_id', mechanicId)
        .eq('status', 'accepted');

    // 3️⃣ Generate 1-hour slots
    for (int s = start; s + 60 <= end; s += 60) {
      final e = s + 60;

      final conflict = booked.any((b) {
        final bs = toMin(b['slot_start']);
        final be = toMin(b['slot_end']);
        return !(e <= bs || s >= be);
      });

      if (!conflict) {
        return {
          'slot_start': '${(s ~/ 60).toString().padLeft(2, '0')}:00:00',
          'slot_end': '${(e ~/ 60).toString().padLeft(2, '0')}:00:00',
        };
      }
    }

    return null;
  }

  Future<void> checkMechanicAvailability() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final now = TimeOfDay.now();
      final nowMinutes = now.hour * 60 + now.minute;

      final res = await supabase
          .from('mechanic_work_schedule')
          .select('mechanic_id, start_time, end_time')
          .eq('work_date', today)
          .eq('is_available', true)
          .limit(1)
          .maybeSingle();

      if (res == null) {
        setState(() {
          mechanicFree = false;
          checkingMechanic = false;
        });
        return;
      }

      // Convert SQL time to minutes
      List<String> start = res['start_time'].split(':');
      List<String> end = res['end_time'].split(':');

      int startMinutes = int.parse(start[0]) * 60 + int.parse(start[1]);
      int endMinutes = int.parse(end[0]) * 60 + int.parse(end[1]);

      if (nowMinutes < startMinutes || nowMinutes > endMinutes) {
        setState(() {
          mechanicFree = false;
          checkingMechanic = false;
        });
        return;
      }

      // ✅ Mechanic is FREE
      setState(() {
        selectedMechanicId = res['mechanic_id'];
        mechanicFree = true;
        checkingMechanic = false;
      });
    } catch (e) {
      setState(() {
        mechanicFree = false;
        checkingMechanic = false;
      });
    }
  }

  Future<void> loadMechanicsOnMap() async {
    final today = DateTime.now().toIso8601String().split('T').first;

    final mechanics = await supabase
        .from('mechanic_locations')
        .select('mechanic_id, latitude, longitude, mechanics(name)');

    mechanicMarkers.clear();

    for (final mech in mechanics) {
      final lat = mech['latitude'];
      final lng = mech['longitude'];

      if (lat == null || lng == null) continue;

      final schedule = await supabase
          .from('mechanic_work_schedule')
          .select()
          .eq('mechanic_id', mech['mechanic_id'])
          .eq('work_date', today)
          .eq('is_available', true)
          .maybeSingle();

      final isAvailable = schedule != null;

      mechanicMarkers.add(
        Marker(
          markerId: MarkerId(mech['mechanic_id']),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isAvailable ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: mech['mechanics']['name'],
            snippet: isAvailable ? "Available" : "Busy",
          ),
        ),
      );
    }

    if (mounted) setState(() {});
  }

  // ---------------- LOAD USER + VEHICLE ----------------
  Future<void> loadInitialData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final userRes = await supabase
        .from('users_data')
        .select()
        .eq('id', user.id)
        .single();

    final vehicleRes = await supabase
        .from('vehicles')
        .select()
        .eq('id', widget.vehicleId)
        .single();

    setState(() {
      userData = userRes;
      vehicleData = vehicleRes;
      loading = false;
    });
  }

  // ---------------- SUBMIT BOOKING ----------------
  Future<void> submitBooking() async {
    if (selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one service")),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      final today = DateTime.now().toIso8601String().split('T').first;

      // 1️⃣ Check mechanic has schedule today
      final mechanicSchedule = await supabase
          .from('mechanic_work_schedule')
          .select('mechanic_id')
          .eq('work_date', today)
          .eq('is_available', true)
          .limit(1)
          .maybeSingle();

      if (mechanicSchedule == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mechanic not available today"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final mechanicId = mechanicSchedule['mechanic_id'];

      // 2️⃣ Find free 1-hour slot
      final slot = await findFreeSlot(mechanicId, today);

      if (slot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No free slots available today"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 3️⃣ Insert booking with slot
      await supabase.from('service_requests_new').insert({
        'user_id': userId,
        'vehicle_id': vehicleData!['id'],
        'problem': selectedServices,
        'description': descCtrl.text.trim(),
        'status': 'pending',
        'mechanic_id': mechanicId,
        'slot_start': slot['slot_start'],
        'slot_end': slot['slot_end'],
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Service booked successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unexpected error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        title: const Text("Service Booking"),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 🗺 MAP SECTION
                  if (userLocation != null)
                    SizedBox(
                      height: 300,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: userLocation!,
                          zoom: 14,
                        ),
                        myLocationEnabled: true,
                        markers: mechanicMarkers,
                        onMapCreated: (c) => mapController = c,
                      ),
                    ),

                  const SizedBox(height: 10),

                  // 🟢🔴 LEGEND
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _Legend(color: Colors.green, text: "Available Mechanic"),
                      _Legend(color: Colors.red, text: "Not Available"),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _infoCard(),
                  const SizedBox(height: 16),
                  serviceTypeField(),
                  descriptionField(),
                  const SizedBox(height: 24),
                  submitButton(),
                ],
              ),
            ),
    );
  }

  Widget _infoCard() {
    if (vehicleData == null) return const SizedBox();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _row("User Name", userData!['name']),
            _row("Registration No", vehicleData!['registration_number']),
            _row("Vehicle Type", vehicleData!['vehicle_type']),
            _row("Brand", vehicleData!['brand']),
            _row("Model", vehicleData!['model']),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 4, child: Text(value)),
        ],
      ),
    );
  }

  Widget roundedField({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget serviceTypeField() {
    return roundedField(
      label: "Service Type",
      child: GestureDetector(
        onTap: () async {
          final List<String> tempSelected = List.from(selectedServices);

          final result = await showModalBottomSheet<List<String>>(
            context: context,
            isScrollControlled: true,
            builder: (_) {
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Select Services",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ...services.map((service) {
                          return CheckboxListTile(
                            value: tempSelected.contains(service),
                            title: Text(service),
                            onChanged: (checked) {
                              setModalState(() {
                                if (checked == true) {
                                  tempSelected.add(service);
                                } else {
                                  tempSelected.remove(service);
                                }
                              });
                            },
                          );
                        }).toList(),

                        const SizedBox(height: 10),

                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, tempSelected);
                          },
                          child: const Text("Done"),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );

          if (result != null) {
            setState(() => selectedServices = result);
          }
        },
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedServices.isEmpty
                    ? "Select services"
                    : selectedServices.join(', '),
                style: TextStyle(
                  fontSize: 16,
                  color: selectedServices.isEmpty ? Colors.grey : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.check_box),
          ],
        ),
      ),
    );
  }

  Widget descriptionField() {
    return roundedField(
      label: "Description",
      child: TextFormField(
        controller: descCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: "Enter problem details (optional)",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: submitting ? null : submitBooking,

        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F4DAB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        child: submitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                "Submit",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;

  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
