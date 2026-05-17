import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_maintance/MainScreens/booking/rating_screen.dart';
import 'package:vehicle_maintance/MainScreens/booking/tracking_screen.dart';
import 'package:vehicle_maintance/MainScreens/bottom_menu.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final supabase = Supabase.instance.client;

  bool showRatingBanner = false;
  String? completedRequestId;
  String? completedMechanicId;

  bool showTrackingBanner = false;
  bool navigatedToTracking = false;

  Set<Marker> mechanicMarkers = {};

  bool mechanicAvailableToday = false;
  bool checkingAvailability = true;
  String? selectedMechanicId; // important

  String? currentRequestId;
  bool waitingForAccept = false;

  LatLng? currentLocation;
  String? currentAddress;

  String? activeTrackingRequestId;
  RealtimeChannel? trackingChannel;

  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> vehicles = [];
  Map<String, dynamic>? selectedVehicle;

  String? selectedProblem;
  final descCtrl = TextEditingController();

  bool get isReady =>
      currentLocation != null && userData != null && vehicles.isNotEmpty;

  bool get isFormReady =>
      selectedProblem != null &&
      selectedVehicle != null &&
      currentLocation != null &&
      userData != null;

  @override
  void initState() {
    super.initState();
    loadAll();
    checkAcceptedRequestFromDB(); // ✅ ADD THIS
  }

  @override
  void dispose() {
    trackingChannel?.unsubscribe();
    descCtrl.dispose();
    super.dispose();
  }

  /*
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadEmergencyMechanics(); // 🔄 refresh markers
  }
*/

  Future<void> checkAcceptedRequestFromDB() async {
    final uid = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('service_requests')
        .select('id, status, mechanic_id')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (!mounted) return;

    bool tracking = false;
    bool ratingBanner = false;
    String? requestId;
    String? mechanicId;

    if (res != null) {
      final status = res['status'];

      // 🟢 TRACKING CASE
      if ([
        'accepted',
        'in_progress',
        'on_the_way',
        'arrived',
      ].contains(status)) {
        tracking = true;
        requestId = res['id'];
      }
      // ⭐ COMPLETED CASE
      else if (status == 'Completed') {
        // 🔍 CHECK IF ALREADY RATED
        final ratingCheck = await supabase
            .from('ratings')
            .select('id')
            .eq('request_id', res['id'])
            .maybeSingle();

        if (ratingCheck == null) {
          ratingBanner = true;
          requestId = res['id'];
          mechanicId = res['mechanic_id'];
        }
      }
    }

    setState(() {
      showTrackingBanner = tracking;
      showRatingBanner = ratingBanner;
      currentRequestId = requestId;
      completedRequestId = requestId;
      completedMechanicId = mechanicId;
    });
  }

  void listenForRequestAcceptance() {
    trackingChannel = supabase
        .channel('booking-status-$currentRequestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'service_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: currentRequestId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord?['status'];

            if (newStatus == 'accepted' && mounted && !navigatedToTracking) {
              navigatedToTracking = true;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrackingScreen(requestId: currentRequestId!),
                ),
              );
            }
          },
        )
        .subscribe();
  }

  Future<bool> isMechanicWorkingNow() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final res = await supabase
        .from('mechanic_work_schedule')
        .select('start_time, end_time')
        .eq('work_date', today)
        .eq('is_available', true)
        .maybeSingle();

    if (res == null) return false;

    final start = res['start_time'].split(':');
    final end = res['end_time'].split(':');

    final startMinutes = int.parse(start[0]) * 60 + int.parse(start[1]);
    final endMinutes = int.parse(end[0]) * 60 + int.parse(end[1]);

    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  Future<void> loadEmergencyMechanics() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // 1️⃣ Fetch schedules
    final schedules = await supabase
        .from('mechanic_work_schedule')
        .select('mechanic_id, start_time, end_time, is_available')
        .eq('work_date', today);

    // 2️⃣ Fetch locations
    final locations = await supabase
        .from('mechanic_locations')
        .select('mechanic_id, latitude, longitude');

    Map<String, dynamic> locationMap = {
      for (var l in locations) l['mechanic_id']: l,
    };

    Set<Marker> markers = {};

    for (final sch in schedules) {
      final mechanicId = sch['mechanic_id'];

      if (!locationMap.containsKey(mechanicId)) continue;

      final loc = locationMap[mechanicId];

      bool isGreen = false;

      // ✅ CHECK SCHEDULE + TIME
      if (sch['is_available'] == true &&
          sch['start_time'] != null &&
          sch['end_time'] != null) {
        final start = sch['start_time'].split(':');
        final end = sch['end_time'].split(':');

        final startMinutes = int.parse(start[0]) * 60 + int.parse(start[1]);
        final endMinutes = int.parse(end[0]) * 60 + int.parse(end[1]);

        if (nowMinutes >= startMinutes && nowMinutes <= endMinutes) {
          isGreen = true;
        }
      }

      markers.add(
        Marker(
          markerId: MarkerId(mechanicId),
          position: LatLng(loc['latitude'], loc['longitude']),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isGreen
                ? BitmapDescriptor
                      .hueGreen // 🟢 AVAILABLE
                : BitmapDescriptor.hueRed, // 🔴 BUSY
          ),
          infoWindow: InfoWindow(
            title: isGreen ? "Available Mechanic" : "Busy Mechanic",
          ),
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      mechanicMarkers = markers;
    });

    debugPrint("✅ Mechanic markers loaded: ${markers.length}");
  }

  Future<void> checkMechanicAvailability() async {
    if (selectedMechanicId == null) return;

    final today = DateTime.now().toIso8601String().split('T').first;

    final res = await supabase
        .from('mechanic_work_schedule')
        .select('id')
        .eq('mechanic_id', selectedMechanicId!)
        .eq('work_date', today)
        .eq('is_available', true)
        .maybeSingle();

    if (!mounted) return;

    setState(() {
      mechanicAvailableToday = res != null;
      checkingAvailability = false;
    });
  }

  // 🔄 LOAD ALL DATA
  Future<void> loadAll() async {
    try {
      await _getLocation();
      await _loadUser();
      await _loadVehicle();
      await loadEmergencyMechanics(); // 🔥 NEW
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  // 📍 LOCATION + ADDRESS
  Future<void> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception("Location service disabled");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied forever");
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    currentLocation = LatLng(pos.latitude, pos.longitude);

    final placemarks = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );
    final p = placemarks.first;

    final parts = [
      p.subLocality,
      p.locality,
      p.administrativeArea,
      p.postalCode,
      p.country,
    ];

    currentAddress = parts
        .where((e) => e != null && e.trim().isNotEmpty)
        .join(", ");
  }

  // 👤 USER
  Future<void> _loadUser() async {
    final uid = supabase.auth.currentUser!.id;
    userData = await supabase
        .from('users_data')
        .select()
        .eq('id', uid)
        .single();
  }

  // 🚗 VEHICLE
  Future<void> _loadVehicle() async {
    final uid = supabase.auth.currentUser!.id;
    final res = await supabase.from('vehicles').select().eq('user_id', uid);
    vehicles = List<Map<String, dynamic>>.from(res);
    if (vehicles.isNotEmpty) selectedVehicle = vehicles.first;
  }

  Future<void> findAvailableMechanic() async {
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

    if (!mounted) return;

    // ❌ No schedule set
    if (res == null) {
      setState(() {
        mechanicAvailableToday = false;
        checkingAvailability = false;
      });
      return;
    }

    // ⏰ Convert SQL time → minutes
    List<String> start = res['start_time'].split(':');
    List<String> end = res['end_time'].split(':');

    int startMinutes = int.parse(start[0]) * 60 + int.parse(start[1]);
    int endMinutes = int.parse(end[0]) * 60 + int.parse(end[1]);

    // ❌ Schedule exists but time crossed
    if (nowMinutes < startMinutes || nowMinutes > endMinutes) {
      setState(() {
        mechanicAvailableToday = false;
        checkingAvailability = false;
      });
      return;
    }

    // ✅ Mechanic available NOW
    setState(() {
      selectedMechanicId = res['mechanic_id'];
      mechanicAvailableToday = true;
      checkingAvailability = false;
    });
  }

  // 🚀 SEND REQUEST
  Future<void> sendRequest() async {
    if (!isFormReady) return;

    final workingNow = await isMechanicWorkingNow();

    // ❌ MECHANIC BUSY
    if (!workingNow) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mechanic is currently busy"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ MECHANIC AVAILABLE
    try {
      final res = await supabase
          .from('service_requests')
          .insert({
            'user_id': supabase.auth.currentUser!.id,
            'vehicle_id': selectedVehicle!['id'],
            'problem': selectedProblem,
            'description': descCtrl.text.trim(),
            'latitude': currentLocation!.latitude,
            'longitude': currentLocation!.longitude,
            'address': currentAddress,
            'status': 'pending',
            'request_type': 'emergency',
          })
          .select()
          .single();

      currentRequestId = res['id'];

      if (!mounted) return;

      // ✅ UI feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request sent. Waiting for mechanic to accept"),
          backgroundColor: Colors.blue,
        ),
      );

      // ✅ START WAITING + REALTIME LISTENER
      setState(() {
        waitingForAccept = true;
      });

      listenForRequestAcceptance(); // 🔥 VERY IMPORTANT
    } catch (e) {
      debugPrint("SEND ERROR => $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send request"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ⏳ WAIT FOR ACCEPT
  Future<void> waitForMechanicResponse() async {
    const maxSeconds = 60;
    const interval = 5;
    int elapsed = 0;

    while (elapsed < maxSeconds && waitingForAccept) {
      await Future.delayed(const Duration(seconds: interval));
      elapsed += interval;

      final res = await supabase
          .from('service_requests')
          .select('status')
          .eq('id', currentRequestId!)
          .single();

      if (res['status'] == 'accepted') {
        waitingForAccept = false;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mechanic accepted your request"),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
    }
  }

  // ================= UI (UNCHANGED) =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        title: const Text("Service Booking"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: !isReady
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.40,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: currentLocation!,
                        zoom: 15,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      markers: {
                        Marker(
                          markerId: const MarkerId("user"),
                          position: currentLocation!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueBlue,
                          ),
                          infoWindow: const InfoWindow(
                            title: "You",
                            snippet: "Your current location",
                          ),
                        ),
                        ...mechanicMarkers,
                      },
                    ),
                  ),

                  /// 🟦🟩🟥 MAP LEGEND (ADD HERE)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        _MapLegend(color: Colors.blue, text: "You"),
                        _MapLegend(
                          color: Colors.green,
                          text: "Available Mechanic",
                        ),
                        _MapLegend(color: Colors.red, text: "Busy Mechanic"),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showTrackingBanner)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TrackingScreen(
                                      requestId: currentRequestId!,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Tracking started · Tap to view",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (showRatingBanner)
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RatingScreen(
                                      requestId: completedRequestId!,
                                      mechanicId: completedMechanicId!,
                                    ),
                                  ),
                                );

                                // 🔥 REFRESH AFTER RETURN
                                await checkAcceptedRequestFromDB();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.star, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text(
                                      "Service completed · Tap to rate",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const Text("Name"),
                          const SizedBox(height: 6),
                          _readonlyBox(userData!['name']),
                          const SizedBox(height: 14),
                          const Text("Vehicle"),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: selectedVehicle,
                            items: vehicles.map((v) {
                              return DropdownMenuItem(
                                value: v,
                                child: Text(
                                  "${v['brand']} ${v['model']} · ${v['registration_number']}",
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => selectedVehicle = v),
                            decoration: _inputDecoration("Select vehicle"),
                          ),
                          const SizedBox(height: 14),
                          const Text("Phone no"),
                          const SizedBox(height: 6),
                          _readonlyBox(userData!['phone']),
                          const SizedBox(height: 14),
                          const Text("Vehicle Problem"),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: selectedProblem,
                            items: const [
                              DropdownMenuItem(
                                value: "Dead batteries",
                                child: Text("Dead batteries"),
                              ),
                              DropdownMenuItem(
                                value: "Low coolant levels",
                                child: Text("Low coolant levels"),
                              ),
                              DropdownMenuItem(
                                value: "Worn brake pads",
                                child: Text("Worn brake pads"),
                              ),
                              DropdownMenuItem(
                                value: "Uneven tyre wear",
                                child: Text("Uneven tyre wear"),
                              ),
                              DropdownMenuItem(
                                value: "Weak AC cooling",
                                child: Text("Weak AC cooling"),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => selectedProblem = v),
                            decoration: _inputDecoration("Select problem"),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: descCtrl,
                            maxLines: 3,
                            decoration: _inputDecoration(
                              "Describe the problem (optional)",
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isFormReady ? sendRequest : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF0F4DAB,
                                ), // 🔵 main color
                                disabledBackgroundColor:
                                    Colors.grey, // ⚫ disabled
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                "Send Request",
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
                ],
              ),
      ),
      bottomNavigationBar: const BottomMenu(selectedIndex: 2),
    );
  }

  Widget _readonlyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _MapLegend extends StatelessWidget {
  final Color color;
  final String text;

  const _MapLegend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on, color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
