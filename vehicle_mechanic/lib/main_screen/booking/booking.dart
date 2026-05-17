import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:vehicle_mechanic/main_screen/booking/notification_service.dart';
import 'package:vehicle_mechanic/main_screen/booking/time_fixing.dart';
//import 'package:vehicle_mechanic/main_screen/booking/notification_service.dart';
import 'package:vehicle_mechanic/main_screen/booking/tracking_screen.dart';
import 'package:vehicle_mechanic/main_screen/bottom_menu.dart';

class BookingScreen extends StatefulWidget {
  final String? requestId;

  const BookingScreen({super.key, this.requestId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? activeTrackingRequest;

  String? mechanicTableId;

  TimeOfDay? fromTime;
  TimeOfDay? toTime;
  bool savingSchedule = false;

  String? todayFrom;
  String? todayTo;

  bool loading = true;
  List<Map<String, dynamic>> requests = [];

  RealtimeChannel? bookingChannel;

  String formatTime(String time) {
    final parts = time.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1];

    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour > 12 ? hour - 12 : hour;
    hour = hour == 0 ? 12 : hour;

    return "$hour:$minute $period";
  }

  bool isCurrentTimeWithinSchedule() {
    if (todayFrom == null || todayTo == null) return false;

    final now = TimeOfDay.now();

    int nowMinutes = now.hour * 60 + now.minute;

    List<String> fromParts = todayFrom!.split(':');
    List<String> toParts = todayTo!.split(':');

    int fromHour = int.parse(fromParts[0]);
    int fromMinute = int.parse(fromParts[1]);

    int toHour = int.parse(toParts[0]);
    int toMinute = int.parse(toParts[1]);

    int fromMinutes = fromHour * 60 + fromMinute;
    int toMinutes = toHour * 60 + toMinute;

    return nowMinutes >= fromMinutes && nowMinutes <= toMinutes;
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> updateMechanicLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await supabase.from('mechanic_locations').upsert({
      'mechanic_id': mechanicTableId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'mechanic_id');

    debugPrint("📍 Location saved for mechanic $mechanicTableId");
  }

  Future<Map<String, dynamic>?> fetchVehicle(String vehicleId) async {
    return await supabase
        .from('vehicles')
        .select('brand, model, registration_number')
        .eq('id', vehicleId)
        .maybeSingle();
  }

  Future<void> _start() async {
    try {
      setState(() => loading = true);

      await loadMechanicId(); // MUST FIRST
      await fetchTodaySchedule();
      await fetchBookings(); // MUST AFTER mechanicTableId

      listenForNewBookings();
    } catch (e) {
      debugPrint("START ERROR => $e");
    } finally {
      if (mounted) {
        setState(() => loading = false); // 🔥 ALWAYS STOP LOADING
      }
    }
  }

  /* Future<void> _init() async {
    try {
      await loadMechanicId();
      await fetchTodaySchedule();
      await fetchBookings();
    } catch (e) {
      debugPrint("INIT ERROR => $e");
      if (mounted) setState(() => loading = false);
    }
  }*/

  Future<void> initAndListen() async {
    await loadMechanicId(); // ✅ FIRST
    await fetchTodaySchedule();
    await fetchBookings();
    listenForNewBookings(); // ✅ LAST
  }

  Future<void> initData() async {
    await loadMechanicId(); // MUST FINISH FIRST
    await fetchTodaySchedule();
    await fetchBookings();
  }

  Future<void> loadMechanicId() async {
    final res = await supabase
        .from('mechanics')
        .select('id')
        .eq('email', supabase.auth.currentUser!.email!)
        .single();

    mechanicTableId = res['id'];
  }

  void listenForNewBookings() {
    bookingChannel = supabase.channel('mechanic-bookings');

    /// 🚨 EMERGENCY REQUESTS
    bookingChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'service_requests',
      callback: (payload) async {
        debugPrint("🔔 EMERGENCY REQUEST ARRIVED");

        // 🔔 Background notification
        await NotificationService.show(
          title: "🚨 Emergency Service Request",
          body: "New emergency request received",
        );

        // 🧠 Foreground popup (dialog)
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text("🚨 Emergency Request"),
              content: const Text("A new emergency request has arrived"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }

        // 🔄 Refresh list
        await fetchBookings();
      },
    );

    /// 🔧 REGULAR REQUESTS (OPTIONAL)
    bookingChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'service_requests_new',
      callback: (payload) async {
        debugPrint("🔔 NEW REGULAR REQUEST RECEIVED");

        await NotificationService.show(
          title: "🔧 New Service Request",
          body: "A new regular service request received.",
        );

        await fetchBookings();
      },
    );

    bookingChannel!.subscribe();
  }

  Future<void> pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        fromTime = picked;
      } else {
        toTime = picked;
      }
    });
  }

  Future<void> fetchTodaySchedule() async {
    if (mechanicTableId == null) return;

    final mechanicId = mechanicTableId!; // ✅ FIX
    final today = DateTime.now().toIso8601String().split('T').first;

    final res = await supabase
        .from('mechanic_work_schedule')
        .select('start_time, end_time, is_available')
        .eq('mechanic_id', mechanicId)
        .eq('work_date', today)
        .maybeSingle();

    if (!mounted) return;

    if (res == null || res['is_available'] == false) {
      setState(() {
        todayFrom = null;
        todayTo = null;
      });
    } else {
      setState(() {
        todayFrom = res['start_time'];
        todayTo = res['end_time'];
      });
    }
  }

  /// 📥 FETCH BOOKINGS
  Future<void> fetchBookings() async {
    if (mechanicTableId == null) return;

    try {
      // 🚨 EMERGENCY REQUESTS (NO FILTERS)
      final emergency = await supabase
          .from('service_requests')
          .select('''
      id, problem, description, latitude, longitude, address, status,
      users_data!service_requests_user_id_fkey ( name, phone ),
      vehicles!service_requests_vehicle_id_fkey ( brand, registration_number )
    ''')
          .eq('status', 'pending'); // ✅ IMPORTANT

      final regular = await supabase
          .from('service_requests_new')
          .select('''
      id, user_id, vehicle_id, problem, description, status,
      users_data!service_requests_new_user_id_fkey ( name, phone )
    ''')
          .eq('status', 'pending'); // ✅ IMPORTANT

      if (!mounted) return;

      setState(() {
        requests = [
          ...emergency.map((e) => {...e, '_type': 'emergency'}),
          ...regular.map((e) => {...e, '_type': 'regular'}),
        ];
      });

      debugPrint("✅ ALL REQUESTS => ${requests.length}");
    } catch (e) {
      debugPrint("❌ FETCH BOOKINGS ERROR => $e");
    }
  }

  /// 📍 ADDRESS
  Future<String> resolveAddress(Map<String, dynamic> req) async {
    if (req['address'] != null && req['address'].toString().trim().isNotEmpty) {
      return req['address'];
    }

    final lat = req['latitude'];
    final lng = req['longitude'];

    if (lat != null && lng != null) {
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        final p = placemarks.first;

        final parts = [
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.postalCode,
          p.country,
        ];

        return parts.where((e) => e != null && e.trim().isNotEmpty).join(", ");
      } catch (_) {
        return "Location unavailable";
      }
    }

    return "Address not available";
  }

  /// ✅ ACCEPT
  Future<void> acceptRequest(Map<String, dynamic> req) async {
    if (mechanicTableId == null) return;

    final String table = req['_type'] == 'emergency'
        ? 'service_requests'
        : 'service_requests_new';

    try {
      await supabase
          .from(table)
          .update({
            'status': req['_type'] == 'emergency' ? 'accepted' : 'time_pending',

            'mechanic_id': mechanicTableId,
          })
          .eq('id', req['id']);

      if (!mounted) return;

      // ✅ Remove from UI list immediately
      if (req['_type'] == 'emergency') {
        setState(() {
          requests.removeWhere((r) => r['id'] == req['id']);
        });
      }

      // ✅ Close any dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("❌ ACCEPT ERROR => $e");
    }
  }

  Future<void> saveTodaySchedule() async {
    if (fromTime == null || toTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select both From and To time"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final fromMinutes = fromTime!.hour * 60 + fromTime!.minute;
    final toMinutes = toTime!.hour * 60 + toTime!.minute;

    if (toMinutes <= fromMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("End time must be after start time"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (mechanicTableId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mechanic profile not loaded"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => savingSchedule = true);

    final today = DateTime.now().toIso8601String().split('T').first;

    String toSqlTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

    // ✅ 1️⃣ SAVE SCHEDULE (MAIN TASK)
    try {
      await supabase.from('mechanic_work_schedule').upsert({
        'mechanic_id': mechanicTableId,
        'work_date': today,
        'start_time': toSqlTime(fromTime!),
        'end_time': toSqlTime(toTime!),
        'is_available': true,
      }, onConflict: 'mechanic_id,work_date');

      if (!mounted) return;

      setState(() {
        todayFrom = toSqlTime(fromTime!);
        todayTo = toSqlTime(toTime!);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Today's schedule saved successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("❌ SCHEDULE SAVE ERROR => $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save schedule"),
          backgroundColor: Colors.red,
        ),
      );
      return; // ⛔ STOP HERE
    }

    // ✅ 2️⃣ UPDATE LOCATION (SECONDARY – MUST NOT FAIL UI)
    try {
      await updateMechanicLocation();
    } catch (e) {
      debugPrint("⚠ LOCATION UPDATE FAILED => $e");
      // ❌ NO snackbar
    } finally {
      if (mounted) {
        setState(() => savingSchedule = false);
      }
    }
  }

  Future<void> declineRequest(Map<String, dynamic> req) async {
    final String table = req['_type'] == 'emergency'
        ? 'service_requests'
        : 'service_requests_new';

    try {
      await supabase
          .from(table)
          .update({'status': 'declined'})
          .eq('id', req['id']);

      if (!mounted) return;

      setState(() {
        requests.removeWhere((r) => r['id'] == req['id']);
      });

      // ✅ Close popup if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request declined"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint("❌ DECLINE ERROR => $e");
    }
  }

  @override
  void dispose() {
    if (bookingChannel != null) {
      supabase.removeChannel(bookingChannel!);
    }
    super.dispose();
  }

  // ================= UI (UNCHANGED) =================
  @override
  Widget build(BuildContext context) {
    //    final bool isAvailableToday = todayFrom != null && todayTo != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Requests"),
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔹 FIXED TOP : TODAY SCHEDULE (ALWAYS VISIBLE)
                // 🔹 FIX TODAY TIME (TOP – SAME PAGE)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Working Time",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => pickTime(true),
                              child: Text(
                                fromTime == null
                                    ? "From Time"
                                    : "From: ${fromTime!.format(context)}",
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => pickTime(false),
                              child: Text(
                                toTime == null
                                    ? "To Time"
                                    : "To: ${toTime!.format(context)}",
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: savingSchedule ? null : saveTodaySchedule,
                          child: savingSchedule
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text("Save Today's Schedule"),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        todayFrom == null || todayTo == null
                            ? "⚠ Schedule not set for today"
                            : isCurrentTimeWithinSchedule()
                            ? "Saved: ${formatTime(todayFrom!)} - ${formatTime(todayTo!)}"
                            : "⚠ Schedule expired for today",
                        style: TextStyle(
                          color: isCurrentTimeWithinSchedule()
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔹 BOTTOM : BOOKINGS / EMPTY STATE
                Expanded(
                  child: requests.isEmpty
                      ? const Center(
                          child: Text(
                            "No service requests available",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final req = requests[index];
                            final bool isEmergency =
                                req['_type'] == 'emergency';

                            final user = req['users_data'];
                            final userName = user?['name'] ?? 'Unknown user';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEmergency
                                          ? '🚨 Emergency Service'
                                          : '🔧 Regular Service',
                                      style: TextStyle(
                                        color: isEmergency
                                            ? Colors.red
                                            : Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    _row(Icons.person, "Name", userName),

                                    // 🚗 VEHICLE
                                    if (isEmergency)
                                      _row(
                                        Icons.directions_car,
                                        "Vehicle",
                                        (req['vehicles'] != null &&
                                                req['vehicles']['brand'] !=
                                                    null &&
                                                req['vehicles']['registration_number'] !=
                                                    null)
                                            ? "${req['vehicles']['brand']} · ${req['vehicles']['registration_number']}"
                                            : "Vehicle not available",
                                      )
                                    else if (req['vehicle_id'] != null)
                                      FutureBuilder<Map<String, dynamic>?>(
                                        future: fetchVehicle(
                                          req['vehicle_id'] as String,
                                        ),
                                        builder: (context, snap) {
                                          if (snap.connectionState ==
                                              ConnectionState.waiting) {
                                            return _row(
                                              Icons.directions_car,
                                              "Vehicle",
                                              "Loading vehicle...",
                                            );
                                          }

                                          if (!snap.hasData ||
                                              snap.data == null) {
                                            return _row(
                                              Icons.directions_car,
                                              "Vehicle",
                                              "Vehicle details unavailable",
                                            );
                                          }

                                          final v = snap.data!;
                                          return _row(
                                            Icons.directions_car,
                                            "Vehicle",
                                            "${v['brand']} · ${v['registration_number']}",
                                          );
                                        },
                                      )
                                    else
                                      _row(
                                        Icons.directions_car,
                                        "Vehicle",
                                        "Vehicle not available",
                                      ),

                                    _row(
                                      Icons.warning,
                                      "Problem",
                                      req['problem'] ?? "—",
                                    ),

                                    _row(
                                      Icons.description,
                                      "Description",
                                      req['description'] ?? "—",
                                    ),

                                    if (isEmergency)
                                      _row(
                                        Icons.location_on,
                                        "Location",
                                        (req['address'] != null &&
                                                req['address']
                                                    .toString()
                                                    .isNotEmpty)
                                            ? req['address']
                                            : "Location not available",
                                      ),

                                    const SizedBox(height: 16),

                                    Row(
                                      children: [
                                        /// DECLINE BUTTON
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              await declineRequest(req);
                                            },

                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),

                                            child: const Text("Decline"),
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        /// ACCEPT BUTTON
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              /// accept request first
                                              await acceptRequest(req);

                                              if (!mounted) return;

                                              /// emergency navigation
                                              if (isEmergency) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        TrackingScreen(
                                                          requestId: req['id'],
                                                          isEmergency: true,
                                                        ),
                                                  ),
                                                );
                                              }
                                              /// regular booking navigation
                                              else {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        TimeFixingPage(
                                                          requestId: req['id']
                                                              .toString(),
                                                          isEmergency: false,
                                                        ),
                                                  ),
                                                );
                                              }
                                            },

                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                            ),

                                            child: Text(
                                              isEmergency
                                                  ? "Start Service"
                                                  : "Fix Time",
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),

      bottomNavigationBar: const BottomMenu(selectedIndex: 1),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    );
  }
}
