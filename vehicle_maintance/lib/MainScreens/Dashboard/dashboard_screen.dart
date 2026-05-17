import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/notification_service.dart';
import 'package:vehicle_maintance/screens/auth/login_screen.dart';
import 'package:vehicle_maintance/MainScreens/bottom_menu.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? scheduledService;

  Map<String, dynamic>? primaryVehicle;
  bool isLoading = true;
  String userName = "";
  Timer? _logoutTimer;
  Timer? serviceTimer;

  @override
  void initState() {
    super.initState();
    fetchUserName();
    fetchPrimaryVehicle();
    fetchScheduledService();
    startServiceTimer(); // ⭐ ADD
    listenServiceUpdates(); // ⭐ ADD THIS
    startAutoLogoutTimer();
  }

  String formatTime(String time) {
    final parts = time.split(':');

    int hour = int.parse(parts[0]);

    final minute = parts[1];

    final period = hour >= 12 ? 'PM' : 'AM';

    hour = hour > 12 ? hour - 12 : hour;

    hour = hour == 0 ? 12 : hour;

    return "$hour:$minute $period";
  }

  void fetchUserName() {
    final user = supabase.auth.currentUser;
    if (user != null && user.userMetadata != null) {
      userName = user.userMetadata!['name'] ?? "User";
    }
  }

  void startServiceTimer() {
    serviceTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      fetchScheduledService();
    });
  }

  void listenServiceUpdates() {
    final userId = supabase.auth.currentUser!.id;

    /// SERVICE REQUEST UPDATE
    supabase
        .channel('user-service-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,

          schema: 'public',

          table: 'service_requests_new',

          callback: (payload) async {
            final data = payload.newRecord;

            if (data['user_id'] == userId && data['status'] == 'time_fixed') {
              await NotificationService.show(
                id: 1,

                title: "Service Scheduled",

                body: "Mechanic fixed your service time",
              );

              fetchScheduledService();
            }
          },
        )
        .subscribe();

    /// FIX TIME INSERT
    supabase
        .channel('fix-time')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,

          schema: 'public',

          table: 'fix_service_time',

          callback: (payload) async {
            if (payload.newRecord['user_id'] == userId) {
              await NotificationService.show(
                id: 2,

                title: "Service Time Fixed",

                body: "Your mechanic scheduled your service",
              );

              fetchScheduledService();
            }
          },
        )
        .subscribe();
  }

  Future<void> fetchScheduledService() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      final services = await supabase
          .from('fix_service_time')
          .select()
          .eq('user_id', userId)
          .order('work_date', ascending: false);

      if (services.isEmpty) {
        setState(() => scheduledService = null);
        return;
      }

      final service = services.first;

      /// TIME CHECK ⭐
      final workDate = service['work_date'];
      final endTime = service['end_time'];

      final serviceEnd = DateTime.parse("$workDate $endTime");

      if (DateTime.now().isAfter(serviceEnd)) {
        /// time expired → hide card
        setState(() {
          scheduledService = null;
        });
        return;
      }

      /// fetch mechanic
      final mechanic = await supabase
          .from('mechanics')
          .select('name,phone,workshop_name')
          .eq('id', service['mechanic_id'])
          .maybeSingle();

      service['mechanics'] = mechanic;

      setState(() {
        scheduledService = service;
      });
    } catch (e) {
      debugPrint("SCHEDULE FETCH ERROR $e");
    }
  }

  Future<void> fetchPrimaryVehicle() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      final response = await supabase
          .from('vehicles')
          .select()
          .eq('user_id', userId)
          .eq('is_primary', true)
          .maybeSingle();

      setState(() {
        primaryVehicle = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void startAutoLogoutTimer() {
    _logoutTimer = Timer(const Duration(hours: 3), () async {
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    });
  }

  int calculateDaysLeft(DateTime expiryDate) {
    return expiryDate.difference(DateTime.now()).inDays;
  }

  double parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0;
  }

  Map<String, dynamic> getServiceStatus(double kmLeft) {
    if (kmLeft <= 0) {
      return {'text': 'Overdue', 'color': Colors.red};
    } else if (kmLeft <= 500) {
      return {'text': 'Service Soon', 'color': Colors.orange};
    } else {
      return {'text': 'Good', 'color': Colors.green};
    }
  }

  @override
  void dispose() {
    supabase.removeAllChannels();

    serviceTimer?.cancel(); // ⭐ ADD

    _logoutTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        title: const Text("Dashboard"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : buildDashboardUI(),
      bottomNavigationBar: const BottomMenu(selectedIndex: 0),
    );
  }

  Widget buildDashboardUI() {
    if (primaryVehicle == null) {
      return const Center(child: Text("No Primary Vehicle Found"));
    }

    final vehicleType = primaryVehicle!['vehicle_type'] ?? "";
    final regNo = primaryVehicle!['registration_number'] ?? "";
    final model = primaryVehicle!['model'] ?? "";
    final insuranceExpiry = DateTime.parse(primaryVehicle!['insurance_expiry']);

    final mileage = parseDouble(primaryVehicle!['mileage']);
    final oilDue = parseDouble(primaryVehicle!['engine_oil_due_km']);
    final generalDue = parseDouble(primaryVehicle!['general_service_due_km']);
    final brakeDue = parseDouble(primaryVehicle!['brake_check_due_km']);

    final oilStatus = getServiceStatus(oilDue - mileage);
    final generalStatus = getServiceStatus(generalDue - mileage);
    final brakeStatus = getServiceStatus(brakeDue - mileage);

    final daysLeft = calculateDaysLeft(insuranceExpiry);

    IconData vehicleIcon = vehicleType.toLowerCase() == "car"
        ? Icons.directions_car
        : Icons.two_wheeler;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Welcome
          Text(
            "Welcome $userName 👋",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          /// Vehicle Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(vehicleIcon, size: 80, color: const Color(0xFF0F4DAB)),
                  const SizedBox(height: 15),
                  buildRow("Vehicle Type", vehicleType),
                  buildRow("Reg No", regNo),
                  buildRow("Model", model),
                  buildRow(
                    "Insurance Expiry",
                    DateFormat('dd MMM yyyy').format(insuranceExpiry),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (scheduledService != null)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Color(0xFF0F4DAB)),
                        SizedBox(width: 8),
                        Text(
                          "Scheduled Service",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10),

                    buildRow(
                      "Problem",
                      scheduledService!['problem'] == null
                          ? "-"
                          : (scheduledService!['problem'] is List
                                ? (scheduledService!['problem'] as List).join(
                                    ", ",
                                  )
                                : scheduledService!['problem'].toString()),
                    ),

                    buildRow("Date", scheduledService!['work_date'] ?? "-"),

                    buildRow(
                      "Time",
                      "${formatTime(scheduledService!['start_time'])} - ${formatTime(scheduledService!['end_time'])}",
                    ),

                    buildRow(
                      "Mechanic",
                      scheduledService!['mechanics']?['name'] ?? "-",
                    ),

                    buildRow(
                      "Phone",
                      scheduledService!['mechanics']?['phone'] ?? "-",
                    ),

                    buildRow(
                      "Workshop",
                      scheduledService!['mechanics']?['workshop_name'] ?? "-",
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          /// Insurance Alert
          if (daysLeft <= 5)
            buildAlertBox(
              daysLeft < 0
                  ? "Insurance Expired ${daysLeft.abs()} days ago"
                  : "Insurance due in $daysLeft days",
              Colors.orange,
            ),

          const SizedBox(height: 25),

          /// Service Status
          const Text(
            "Service Status",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          buildStatusCard("Engine Oil", oilStatus),
          buildStatusCard("General Service", generalStatus),
          buildStatusCard("Brake Check", brakeStatus),
        ],
      ),
    );
  }

  Widget buildRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAlertBox(String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusCard(String title, Map<String, dynamic> status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.build),
        title: Text(title),
        trailing: Text(
          status['text'],
          style: TextStyle(color: status['color'], fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
